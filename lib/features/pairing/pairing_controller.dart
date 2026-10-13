import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/constants.dart';
import '../../core/logging/app_logger.dart';
import '../../device/ble/background_service.dart';
import '../../device/ble/ble_bridge.dart';
import '../../device/ble/connection.dart';
import '../../device/ble/known_device_store.dart';
import '../../device/ble/pairing_failure.dart';
import '../../device/ble/reconnect_policy.dart';
import '../../device/ble/scanner.dart';
import '../../device/device_state.dart';

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
  });

  final BleBridge bridge;
  final DeviceScanner scanner;
  final DeviceConnection connection;
  final KnownDeviceStore knownDevices;
  final AppLogger logger;
  final ReconnectPolicy reconnectPolicy;
  final BackgroundConnection background;

  CaipoLinkState link = CaipoLinkState.disconnected;
  PairingFailure? failure;
  String bluetoothState = 'unknown';
  bool scanning = false;
  String? connectedId;
  int? batteryPercent;
  final List<PairingDevice> devices = [];

  StreamSubscription<String>? _stateSub;
  StreamSubscription<DisconnectEvent>? _dropSub;
  Timer? _linkWatch;
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
      bluetoothState = await bridge.hostApi.getBluetoothState();
    } catch (error) {
      logger.warn('Bluetooth state unavailable: $error');
      failure = PairingFailure.adapterUnavailable;
    }
    _publishDevices();
    final known = knownDevices.load();
    if (known.isNotEmpty && bluetoothState == 'on') {
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
    bluetoothState = await bridge.hostApi.getBluetoothState();
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
      final session = await CaipoDeviceConnection(deviceId: id, connection: connection).connect();
      if (generation != _reconnectGeneration) return;
      connectedId = id;
      batteryPercent = session.batteryPercent;
      link = CaipoLinkState.connected;
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
      failure = error.failure;
      link = CaipoLinkState.pairingFailed;
      connectedId = null;
    } catch (error, stack) {
      logger.error('Connect failed', error: error, stackTrace: stack);
      failure = PairingFailure.adapterUnavailable;
      link = CaipoLinkState.pairingFailed;
      connectedId = null;
    }
    notifyListeners();
  }

  Future<void> forget(String id) async {
    _reconnectGeneration++;
    _linkWatch?.cancel();
    if (connectedId == id) {
      await connection.disconnect(id);
      connectedId = null;
      link = CaipoLinkState.disconnected;
    }
    await knownDevices.remove(id);
    _publishDevices();
    notifyListeners();
  }

  Future<void> openSettings() => bridge.hostApi.openBluetoothSettings();

  Future<void> enableBluetooth() => bridge.hostApi.enableBluetooth();

  Future<void> _reconnect(PairingFailure reason) async {
    final id = connectedId;
    if (id == null) return;
    final generation = ++_reconnectGeneration;
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
          notifyListeners();
          return;
        }
        await connection.connect(id);
        if (generation != _reconnectGeneration) return;
        link = CaipoLinkState.connected;
        failure = null;
        connectedId = id;
        _watchLink(id);
        notifyListeners();
        return;
      } on ConnectFailed catch (error) {
        logger.warn('Reconnect attempt ${attempt + 1} failed: ${error.failure.name}');
      }
    }
    if (generation != _reconnectGeneration) return;
    failure = PairingFailure.reconnectExhausted;
    link = CaipoLinkState.disconnected;
    connectedId = null;
    notifyListeners();
  }

  void _watchLink(String id) {
    _linkWatch?.cancel();
    _linkWatch = Timer.periodic(kLinkPollInterval, (_) async {
      if (link != CaipoLinkState.connected || connectedId != id) return;
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
    _stateSub?.cancel();
    _dropSub?.cancel();
    super.dispose();
  }
}
