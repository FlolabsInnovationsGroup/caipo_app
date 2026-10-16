import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/constants.dart';
import '../../core/logging/app_logger.dart';
import '../../device/ble/background_service.dart';
import '../../device/ble/ble_bridge.dart';
import '../../device/ble/connection.dart';
import '../../device/ble/known_device_store.dart';
import '../../device/ble/link_liveness.dart';
import '../../device/ble/pairing_failure.dart';
import '../../core/config/proposed_flags.dart';
import '../../device/ble/reconnect_policy.dart';
import '../../device/protocol/transfer_archive.dart';
import '../../device/protocol/proposed_commands.dart';
import '../../device/info/device_info.dart';
import '../../device/audio/codec_negotiation.dart';
import '../../device/ble/scanner.dart';
import '../../device/device_state.dart';
import '../../device/protocol/device_transfer_session.dart';
import '../../device/protocol/messages.dart';
import '../conversation/voice_loop.dart';

class PairingDevice {
  const PairingDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.batteryPercent,
    required this.known,
    required this.nearby,
  });

  final String id;
  final String name;
  final int? rssi;
  final int? batteryPercent;
  final bool known;
  final bool nearby;
}

class PairingController extends ChangeNotifier {
  PairingController({
    required this.bridge,
    required this.scanner,
    required this.connection,
    required this.knownDevices,
    required this.logger,
    this.reconnectPolicy = const ReconnectPolicy(),
    this.background = const BackgroundConnection(),
    this.voice,
    required this.archive,
    bool Function()? autoConnect,
  }) : autoConnect = autoConnect ?? (() => true) {
    voice?.addListener(notifyListeners);
  }

  final BleBridge bridge;
  final DeviceScanner scanner;
  final DeviceConnection connection;
  final KnownDeviceStore knownDevices;
  final AppLogger logger;
  final ReconnectPolicy reconnectPolicy;
  final BackgroundConnection background;
  final VoiceLoopController? voice;
  final TransferArchive archive;
  final bool Function() autoConnect;

  CaipoLinkState link = CaipoLinkState.disconnected;
  PairingFailure? failure;
  String? codecError;
  String bluetoothState = 'unknown';
  bool scanning = false;
  String? connectedId;
  int? batteryPercent;
  DeviceInformation? information;
  DeviceStatus? deviceStatus;
  CommandResult? lastCommandResult;
  StreamReady? streamReady;
  var bonded = false;
  final List<PairingDevice> devices = [];

  StreamSubscription<String>? _stateSub;
  StreamSubscription<DisconnectEvent>? _dropSub;
  StreamSubscription<CharacteristicEvent>? _activitySub;
  Timer? _linkWatch;
  DeviceTransferSession? _transfers;
  final LinkLiveness _liveness = LinkLiveness();
  final HeartbeatTracker _heartbeats = HeartbeatTracker();
  Completer<void> _codecGate = Completer<void>();
  int _reconnectGeneration = 0;

  Future<void> start() async {
    bridge.bind();
    _stateSub ??= bridge.bluetoothState.stream.listen((state) {
      bluetoothState = state;
      if (state == 'off') failure = PairingFailure.bluetoothOff;
      if (state == 'on' && failure == PairingFailure.bluetoothOff) failure = null;
      notifyListeners();
    });
    _dropSub ??= bridge.disconnected.stream.listen((event) {
      if (connectedId == null || event.id.toLowerCase() != connectedId!.toLowerCase()) return;
      if (link == CaipoLinkState.connected || link == CaipoLinkState.reconnecting) {
        unawaited(_reconnect(failureFromNativeError(event.error) ?? PairingFailure.linkLost));
      }
    });
    logger.info('BLE background restore id ${background.restoreIdentifier}');
    try {
      bluetoothState = await bridge.controller.getBluetoothState();
    } catch (error) {
      logger.warn('Bluetooth state unavailable: $error');
      failure = PairingFailure.adapterUnavailable;
    }
    _publishDevices();
    final known = knownDevices.load();
    if (known.isNotEmpty && bluetoothState == 'on' && autoConnect()) {
      unawaited(connect(known.last.id, known.last.name));
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    failure = null;
    final permission = await _ensurePermissions();
    if (permission != null) {
      failure = permission;
      link = CaipoLinkState.pairingFailed;
      notifyListeners();
      return;
    }
    bluetoothState = await bridge.controller.getBluetoothState();
    if (bluetoothState == 'off') {
      failure = PairingFailure.bluetoothOff;
      link = CaipoLinkState.pairingFailed;
      notifyListeners();
      return;
    }
    if (bluetoothState == 'unauthorized') {
      failure = PairingFailure.bluetoothUnauthorized;
      link = CaipoLinkState.pairingFailed;
      notifyListeners();
      return;
    }
    if (bluetoothState == 'unsupported') {
      failure = PairingFailure.bluetoothUnsupported;
      link = CaipoLinkState.pairingFailed;
      notifyListeners();
      return;
    }
    scanning = true;
    link = CaipoLinkState.scanning;
    notifyListeners();
    try {
      final seen = await scanner.scan();
      if (seen.isEmpty && knownDevices.load().isEmpty) {
        failure = PairingFailure.notFound;
        link = CaipoLinkState.notFound;
      } else if (connectedId == null) {
        link = CaipoLinkState.disconnected;
      }
      _merge(seen);
    } catch (error, stack) {
      logger.error('Scan failed', error: error, stackTrace: stack);
      failure = PairingFailure.scanFailed;
      link = CaipoLinkState.pairingFailed;
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(String id, String name) async {
    _reconnectGeneration++;
    final generation = _reconnectGeneration;
    failure = null;
    link = CaipoLinkState.connecting;
    notifyListeners();
    try {
      _attachTransfers(id);
      final session = await CaipoDeviceConnection(deviceId: id, connection: connection).connect();
      if (generation != _reconnectGeneration) {
        if (!_codecGate.isCompleted) _codecGate.complete();
        return;
      }
      connectedId = id;
      batteryPercent = session.batteryPercent;
      information = session.information;
      bonded = true;
      _noteCodec(session.codec);
      unawaited(_sendProposedHello(id));
      link = CaipoLinkState.connected;
      _liveness.arm();
      await knownDevices.save(
        KnownDevice(
          id: id,
          name: name,
          batteryPercent: session.batteryPercent,
          lastSeen: DateTime.now(),
        ),
      );
      _watchLink(id);
      _publishDevices();
    } on ConnectFailed catch (error) {
      if (generation != _reconnectGeneration) return;
      await _transfers?.stop();
      _transfers = null;
      failure = error.failure;
      link = CaipoLinkState.pairingFailed;
      connectedId = null;
      if (!_codecGate.isCompleted) _codecGate.complete();
    } catch (error, stack) {
      logger.error('Connect failed', error: error, stackTrace: stack);
      await _transfers?.stop();
      _transfers = null;
      failure = PairingFailure.adapterUnavailable;
      link = CaipoLinkState.pairingFailed;
      connectedId = null;
      if (!_codecGate.isCompleted) _codecGate.complete();
    }
    notifyListeners();
  }

  int? get connectedRssi {
    final id = connectedId;
    if (id == null) return null;
    for (final device in devices) {
      if (device.id == id) return device.rssi;
    }
    return null;
  }

  Future<void> rename(String name) async {
    final id = connectedId;
    final trimmed = name.trim();
    if (id == null || trimmed.isEmpty) return;
    final previous = knownDevices.load().where((item) => item.id == id).toList();
    final current = previous.isEmpty
        ? KnownDevice(id: id, name: trimmed, batteryPercent: batteryPercent, lastSeen: DateTime.now())
        : previous.first.copyWith(name: trimmed, lastSeen: DateTime.now());
    await knownDevices.save(current);
    _publishDevices();
    notifyListeners();
  }

  Future<void> forget(String id) async {
    _reconnectGeneration++;
    _linkWatch?.cancel();
    await _transfers?.stop();
    _transfers = null;
    await _activitySub?.cancel();
    _activitySub = null;
    if (connectedId == id) {
      await connection.disconnect(id);
      connectedId = null;
      information = null;
      bonded = false;
      deviceStatus = null;
      streamReady = null;
      link = CaipoLinkState.disconnected;
    }
    await knownDevices.remove(id);
    _publishDevices();
    notifyListeners();
  }

  Future<void> openSettings() => bridge.controller.openBluetoothSettings();

  Future<void> enableBluetooth() => bridge.controller.enableBluetooth();

  Future<void> _reconnect(PairingFailure reason) async {
    final id = connectedId;
    if (id == null) return;
    final generation = ++_reconnectGeneration;
    await _transfers?.stop();
    _transfers = null;
    failure = reason;
    link = CaipoLinkState.reconnecting;
    notifyListeners();
    for (var attempt = 0; attempt < reconnectPolicy.maxAttempts; attempt++) {
      final delay = reconnectPolicy.delayForAttempt(attempt);
      if (delay == null || generation != _reconnectGeneration) return;
      await Future<void>.delayed(delay);
      if (generation != _reconnectGeneration) return;
      try {
        final up = await connection.isConnected(id);
        if (up) {
          link = CaipoLinkState.connected;
          failure = null;
          _attachTransfers(id);
          if (!_codecGate.isCompleted) _codecGate.complete();
          _liveness.arm();
          _watchLink(id);
          notifyListeners();
          return;
        }
        _attachTransfers(id);
        final session = await connection.connect(id);
        if (generation != _reconnectGeneration) return;
        _noteCodec(session.codec);
        link = CaipoLinkState.connected;
        failure = null;
        connectedId = id;
        batteryPercent = session.batteryPercent;
        information = session.information;
        bonded = true;
        unawaited(_sendProposedHello(id));
        _liveness.arm();
        _watchLink(id);
        notifyListeners();
        return;
      } on ConnectFailed catch (error) {
        await _transfers?.stop();
        _transfers = null;
        logger.warn('Reconnect attempt ${attempt + 1} failed: ${error.failure.name}');
      }
    }
    if (generation != _reconnectGeneration) return;
    await _transfers?.stop();
    _transfers = null;
    failure = PairingFailure.reconnectExhausted;
    link = CaipoLinkState.disconnected;
    connectedId = null;
    notifyListeners();
  }

  void _noteCodec(NegotiatedCodec? codec) {
    if (codec != null && codec.id == kTargetCodecId) {
      codecError = null;
    } else if (codec == null) {
      codecError = 'Codec 21 is required. The device did not report a codec.';
    } else {
      codecError = 'Codec 21 is the only supported format. The device reported codec ${codec.id}.';
    }
    if (!_codecGate.isCompleted) _codecGate.complete();
  }

  void _attachTransfers(String id) {
    _listenForActivity(id);
    if (!_codecGate.isCompleted) _codecGate.complete();
    final gate = Completer<void>();
    _codecGate = gate;
    final previous = _transfers;
    if (previous != null) unawaited(previous.stop());
    _transfers = DeviceTransferSession(
      deviceId: id,
      connection: connection,
      events: bridge.characteristicValues.stream,
      logger: logger,
      onTransferStarted: () => voice?.markListening(),
      onAbandoned: (partial) async {
        // Same archive while the screen is locked or the process is in the background.
        await archive.savePartial(partial);
      },
      onCompleted: (payload, type) async {
        await archive.save(bytes: payload, contentType: type);
        await gate.future;
        final loop = voice;
        if (loop == null) return;
        final live = connectedId?.toLowerCase() == id.toLowerCase();
        await loop.acceptTransfer(
          id,
          payload,
          type,
          codecSupported: codecError == null,
          runLoop: live,
          persist: false,
        );
      },
    )..start();
  }

  void _listenForActivity(String id) {
    _activitySub?.cancel();
    _activitySub = bridge.characteristicValues.stream.listen((event) {
      if (event.id.toLowerCase() != id.toLowerCase()) return;
      _liveness.mark();
      if (event.characteristicUuid.toLowerCase() != kCommandCharacteristicUuid.toLowerCase()) return;
      try {
        if (kProposedCommands || kProposedStream) {
          final proposed = decodeProposedCommand(event.value);
          if (proposed is StreamReady && kProposedStream) {
            streamReady = proposed;
            notifyListeners();
            return;
          }
          if (kProposedCommands && proposed is DeviceStatus) {
            deviceStatus = proposed;
            if (proposed.batteryPercent <= 100) batteryPercent = proposed.batteryPercent;
            notifyListeners();
            return;
          }
          if (kProposedCommands && proposed is CommandResult) {
            lastCommandResult = proposed;
            notifyListeners();
            return;
          }
        }
        final message = decodeWire(event.value);
        if (message is! HeartbeatMessage) return;
        final gap = _heartbeats.note(message.counter);
        if (gap != null) {
          logger.warn('Heartbeat gap: expected ${gap.expected}, received ${gap.actual}.');
        }
      } on FormatException catch (error) {
        logger.warn('Command notification was not a heartbeat: $error');
      }
    });
  }

  void _watchLink(String id) {
    _linkWatch?.cancel();
    _linkWatch = Timer.periodic(kLinkPollInterval, (_) async {
      if (link != CaipoLinkState.connected || connectedId != id) return;
      if (_liveness.silent) {
        unawaited(_reconnect(PairingFailure.linkLost));
        return;
      }
      try {
        final up = await connection.isConnected(id);
        if (!up) unawaited(_reconnect(PairingFailure.linkLost));
      } catch (_) {}
    });
  }

  void _merge(List<SeenDevice> seen) {
    final known = {for (final device in knownDevices.load()) device.id: device};
    for (final device in seen) {
      known[device.id] = KnownDevice(
        id: device.id,
        name: device.name.isEmpty ? (known[device.id]?.name ?? 'Unnamed device') : device.name,
        batteryPercent: known[device.id]?.batteryPercent,
        rssi: device.rssi,
        lastSeen: DateTime.now(),
      );
    }
    devices
      ..clear()
      ..addAll(
        known.values.map((device) {
          final live = seen.where((item) => item.id == device.id).toList();
          return PairingDevice(
            id: device.id,
            name: device.name,
            rssi: live.isEmpty ? device.rssi : live.first.rssi,
            batteryPercent: device.batteryPercent ?? (connectedId == device.id ? batteryPercent : null),
            known: knownDevices.load().any((item) => item.id == device.id),
            nearby: live.isNotEmpty,
          );
        }),
      );
    devices.sort((a, b) => (b.rssi ?? -200).compareTo(a.rssi ?? -200));
  }

  Future<void> sendProposed(Uint8List frame) async {
    final id = connectedId;
    if (!kProposedCommands || id == null) return;
    await connection.writeCommand(id, frame);
  }

  /// START_STREAM or STOP_STREAM. Does nothing while the stream flag is off.
  Future<void> sendStream(Uint8List frame) async {
    final id = connectedId;
    if (!kProposedStream || id == null) return;
    streamReady = null;
    await connection.writeCommand(id, frame);
  }

  Future<void> _sendProposedHello(String id) async {
    if (!kProposedCommands) return;
    final unix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await connection.writeCommand(id, encodeSetTime(unix));
    await connection.writeCommand(id, encodeGetStatus());
  }

  void _publishDevices() => _merge(const []);

  Future<PairingFailure?> _ensurePermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) return PairingFailure.permissionDenied;
      return null;
    }
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) {
      final notifications = await Permission.notification.request();
      if (!notifications.isGranted) {
        failure = PairingFailure.notificationPermissionDenied;
      }
      return null;
    }
    final location = await Permission.locationWhenInUse.request();
    if (!location.isGranted) return PairingFailure.locationPermissionDenied;
    if (!connect.isGranted) return PairingFailure.permissionDenied;
    return null;
  }

  @override
  void dispose() {
    _reconnectGeneration++;
    _linkWatch?.cancel();
    _transfers?.stop();
    _activitySub?.cancel();
    _stateSub?.cancel();
    _dropSub?.cancel();
    super.dispose();
  }
}
