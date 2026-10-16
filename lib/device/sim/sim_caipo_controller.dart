import 'dart:async';
import 'dart:io';

import 'package:caipo_app/gen/ble_api.g.dart';
import 'package:flutter/services.dart';

import '../../core/config/constants.dart';
import '../audio/opus_codec.dart';
import '../audio/wav_pcm.dart';
import '../ble/ble_bridge.dart';
import '../ble/ble_controller.dart';
import '../protocol/incoming_transfer.dart';
import '../protocol/messages.dart';
import '../protocol/proposed_commands.dart';
import '../protocol/transfer_manager.dart';
import 'sim_mjpeg_server.dart';

/// In-app CAIPO. It speaks the BLE contract in memory.
///
/// Recordings are the bundled speech WAV, encoded with libopus. Replies are
/// decoded from the same container and saved as WAV. This is not the ESP32.
class SimCaipoController implements BleController {
  SimCaipoController(this._bridge, {this._replyDirectory});

  static const deviceId = 'sim-caipo-1';
  static const deviceName = 'CAIPO-SIM';

  final BleBridge _bridge;
  final Directory? _replyDirectory;
  final IncomingTransfer _incoming = IncomingTransfer();
  final Set<String> _subscribed = {};
  Timer? _heartbeat;
  var _counter = 0;
  var _connected = false;
  PreparedTransfer? _sending;
  var _awaitingReady = false;
  Uint8List? _recording;
  File? lastReplyWav;
  void Function(String path)? onReplySaved;
  final SimMjpegServer _stream = SimMjpegServer();

  /// Opens a bridge that never calls the phone radio.
  static BleBridge open({Directory? replyDirectory}) {
    final bridge = BleBridge(controller: _PlaceholderController());
    bridge.controller = SimCaipoController(bridge, replyDirectory: replyDirectory);
    return bridge;
  }

  @override
  Future<void> startScan(int timeoutSeconds, List<String> serviceUuids) async {
    final wanted = serviceUuids.map((item) => item.toLowerCase());
    if (wanted.isNotEmpty && !wanted.contains(kPrimaryServiceUuid.toLowerCase())) return;
    _bridge.onPeripheralDiscovered(
      BlePeripheral(
        uuid: deviceId,
        name: deviceName,
        rssi: -52,
        serviceUuids: [kPrimaryServiceUuid],
      ),
    );
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> manageDevice(String uuid, bool requiresBond) async {
    if (!_same(uuid)) {
      _bridge.onPeripheralDisconnected(uuid, 'not_found');
      return;
    }
    _connected = true;
    _bridge.onDeviceReady(deviceId, [
      BleService(
        uuid: kPrimaryServiceUuid,
        characteristicUuids: [
          kInboundCharacteristicUuid,
          kAudioCodecCharacteristicUuid,
          kOutboundCharacteristicUuid,
          kCommandCharacteristicUuid,
        ],
      ),
      BleService(
        uuid: kBatteryServiceUuid,
        characteristicUuids: [kBatteryLevelCharacteristicUuid],
      ),
      BleService(
        uuid: kDeviceInfoServiceUuid,
        characteristicUuids: [
          kManufacturerNameCharacteristicUuid,
          kModelNumberCharacteristicUuid,
          kSerialNumberCharacteristicUuid,
          kFirmwareRevisionCharacteristicUuid,
        ],
      ),
    ]);
  }

  @override
  Future<void> unmanageDevice(String uuid) async {
    _heartbeat?.cancel();
    unawaited(_stream.stop());
    _connected = false;
    _subscribed.clear();
    _sending = null;
    _bridge.onPeripheralDisconnected(uuid, 'cancelled');
  }

  @override
  Future<bool> requestBond(String uuid) async => _same(uuid) && _connected;

  @override
  Future<Uint8List> readCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    if (!_connected || !_same(peripheralUuid)) {
      throw StateError('Simulated CAIPO is not connected.');
    }
    final id = characteristicUuid.toLowerCase();
    if (id == kAudioCodecCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList([kCodecOpus16kHz]);
    }
    if (id == kBatteryLevelCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList([87]);
    }
    if (id == kManufacturerNameCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList('FloLabs'.codeUnits);
    }
    if (id == kModelNumberCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList('CAIPO-SIM'.codeUnits);
    }
    if (id == kSerialNumberCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList('SIM-0001'.codeUnits);
    }
    if (id == kFirmwareRevisionCharacteristicUuid.toLowerCase()) {
      return Uint8List.fromList('sim-0'.codeUnits);
    }
    throw StateError('Simulated characteristic $characteristicUuid is not readable.');
  }

  @override
  Future<void> writeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data,
  ) async {
    if (!_connected || !_same(peripheralUuid)) {
      throw StateError('Simulated CAIPO is not connected.');
    }
    if (characteristicUuid.toLowerCase() == kCommandCharacteristicUuid.toLowerCase()) {
      await _onCommand(data);
      return;
    }
    if (characteristicUuid.toLowerCase() != kOutboundCharacteristicUuid.toLowerCase()) {
      return;
    }
    _onAppWrite(data);
  }

  @override
  Future<void> subscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    if (!_connected || !_same(peripheralUuid)) {
      throw StateError('Simulated CAIPO is not connected.');
    }
    _subscribed.add(characteristicUuid.toLowerCase());
    if (characteristicUuid.toLowerCase() == kCommandCharacteristicUuid.toLowerCase()) {
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(kHeartbeatPeriod, (_) => _beat());
      _beat();
    }
    if (characteristicUuid.toLowerCase() == kInboundCharacteristicUuid.toLowerCase()) {
      await _startRecording();
    }
  }

  @override
  Future<void> unsubscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    _subscribed.remove(characteristicUuid.toLowerCase());
    if (characteristicUuid.toLowerCase() == kCommandCharacteristicUuid.toLowerCase()) {
      _heartbeat?.cancel();
    }
  }

  @override
  Future<String> getBluetoothState() async => 'on';

  @override
  Future<bool> enableBluetooth() async => true;

  @override
  Future<bool> isPeripheralConnected(String uuid) async => _connected && _same(uuid);

  @override
  Future<int> maximumWriteLength(String peripheralUuid) async => kNegotiatedMtuBytes - 3;

  @override
  Future<void> startRssiStreaming(String uuid) async {
    if (_connected && _same(uuid)) _bridge.onRssiUpdate(deviceId, -52);
  }

  @override
  Future<void> stopRssiStreaming(String uuid) async {}

  @override
  Future<void> openBluetoothSettings() async {}

  Future<void> _onCommand(Uint8List data) async {
    if (data.isEmpty) return;
    if (data[0] == kProposedStopStream) {
      await _stream.stop();
      return;
    }
    if (data[0] != kProposedStartStream) return;
    final ready = await _stream.start();
    _emit(kCommandCharacteristicUuid, encodeStreamReady(ready));
  }

  void _beat() {
    if (!_connected || !_subscribed.contains(kCommandCharacteristicUuid.toLowerCase())) return;
    _emit(kCommandCharacteristicUuid, encodeHeartbeat(_counter));
    _counter = (_counter + 1) & 0xFF;
  }

  Future<void> _startRecording() async {
    final payload = await _speechOpus();
    _sending = const TransferManager().prepare(
      payload: payload,
      transferId: 1,
      contentType: kContentTypeAudio,
    );
    _awaitingReady = true;
    _emit(kInboundCharacteristicUuid, _sending!.request);
  }

  Future<Uint8List> _speechOpus() async {
    final cached = _recording;
    if (cached != null) return cached;
    await OpusCodec.ensureLoaded();
    final data = await rootBundle.load('assets/sim/speech.wav');
    final wav = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final encoded = OpusCodec.shared.encodeWav(wav);
    _recording = encoded;
    return encoded;
  }

  void _onAppWrite(Uint8List data) {
    final message = decodeWire(data);
    final sending = _sending;
    if (sending != null && message is HandshakeMessage && message.transferId == sending.transferId) {
      if (_awaitingReady && message.kind == TransferMessageKind.transferReady) {
        _awaitingReady = false;
        _emit(kInboundCharacteristicUuid, sending.metadata);
        for (final chunk in sending.chunks) {
          _emit(kInboundCharacteristicUuid, chunk);
        }
        return;
      }
      if (message.kind == TransferMessageKind.transferAck) {
        _sending = null;
        _awaitingReady = false;
        return;
      }
    }
    if (sending != null &&
        message is ErrorMessage &&
        message.transferId == sending.transferId &&
        message.namesChunk &&
        message.sequence < sending.chunks.length) {
      _emit(kInboundCharacteristicUuid, sending.chunks[message.sequence]);
      return;
    }
    final reply = _incoming.handle(data);
    if (reply == null) return;
    final frame = reply.frame;
    if (frame != null) _emit(kInboundCharacteristicUuid, frame);
    final payload = reply.payload;
    if (payload != null) _saveReply(payload);
  }

  void _saveReply(Uint8List payload) {
    final dir = _replyDirectory ?? Directory('${Directory.systemTemp.path}${Platform.pathSeparator}caipo-sim-replies');
    dir.createSync(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pcm = OpusCodec.shared.decodeContainer(payload);
    final wav = writePcmWav(pcm);
    final file = File('${dir.path}${Platform.pathSeparator}reply_$stamp.wav');
    file.writeAsBytesSync(wav);
    lastReplyWav = file;
    onReplySaved?.call(file.path);
  }

  void _emit(String characteristicUuid, Uint8List value) {
    if (!_subscribed.contains(characteristicUuid.toLowerCase())) return;
    _bridge.onCharacteristicValueUpdated(deviceId, kPrimaryServiceUuid, characteristicUuid, value);
  }

  bool _same(String uuid) => uuid.toLowerCase() == deviceId.toLowerCase();
}

class _PlaceholderController implements BleController {
  @override
  Future<bool> enableBluetooth() async => false;

  @override
  Future<String> getBluetoothState() async => 'off';

  @override
  Future<bool> isPeripheralConnected(String uuid) async => false;

  @override
  Future<int> maximumWriteLength(String peripheralUuid) async => 20;

  @override
  Future<void> manageDevice(String uuid, bool requiresBond) async {}

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<Uint8List> readCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async => Uint8List(0);

  @override
  Future<bool> requestBond(String uuid) async => false;

  @override
  Future<void> startRssiStreaming(String uuid) async {}

  @override
  Future<void> startScan(int timeoutSeconds, List<String> serviceUuids) async {}

  @override
  Future<void> stopRssiStreaming(String uuid) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> subscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async {}

  @override
  Future<void> unmanageDevice(String uuid) async {}

  @override
  Future<void> unsubscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) async {}

  @override
  Future<void> writeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data,
  ) async {}
}
