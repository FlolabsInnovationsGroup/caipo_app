import 'dart:typed_data';

import 'package:caipo_app/gen/ble_api.g.dart';

/// The radio the rest of the app talks to.
///
/// [NativeBleController] is the phone stack. [SimCaipoController] is the
/// in-app device used when `DEVICE_MODE=sim`.
abstract class BleController {
  Future<void> startScan(int timeoutSeconds, List<String> serviceUuids);
  Future<void> stopScan();
  Future<void> manageDevice(String uuid, bool requiresBond);
  Future<void> unmanageDevice(String uuid);
  Future<bool> requestBond(String uuid);
  Future<Uint8List> readCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );
  Future<void> writeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data,
  );
  Future<void> subscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );
  Future<void> unsubscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );
  Future<String> getBluetoothState();
  Future<bool> enableBluetooth();
  Future<bool> isPeripheralConnected(String uuid);
  Future<int> maximumWriteLength(String peripheralUuid);
  Future<void> startRssiStreaming(String uuid);
  Future<void> stopRssiStreaming(String uuid);
  Future<void> openBluetoothSettings();
}

class NativeBleController implements BleController {
  NativeBleController({BleHostApi? api}) : _api = api ?? BleHostApi();

  final BleHostApi _api;

  @override
  Future<void> startScan(int timeoutSeconds, List<String> serviceUuids) =>
      _api.startScan(timeoutSeconds, serviceUuids);

  @override
  Future<void> stopScan() => _api.stopScan();

  @override
  Future<void> manageDevice(String uuid, bool requiresBond) => _api.manageDevice(uuid, requiresBond);

  @override
  Future<void> unmanageDevice(String uuid) => _api.unmanageDevice(uuid);

  @override
  Future<bool> requestBond(String uuid) => _api.requestBond(uuid);

  @override
  Future<Uint8List> readCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) => _api.readCharacteristic(peripheralUuid, serviceUuid, characteristicUuid);

  @override
  Future<void> writeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data,
  ) => _api.writeCharacteristic(peripheralUuid, serviceUuid, characteristicUuid, data);

  @override
  Future<void> subscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) => _api.subscribeCharacteristic(peripheralUuid, serviceUuid, characteristicUuid);

  @override
  Future<void> unsubscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  ) => _api.unsubscribeCharacteristic(peripheralUuid, serviceUuid, characteristicUuid);

  @override
  Future<String> getBluetoothState() => _api.getBluetoothState();

  @override
  Future<bool> enableBluetooth() => _api.enableBluetooth();

  @override
  Future<bool> isPeripheralConnected(String uuid) => _api.isPeripheralConnected(uuid);

  @override
  Future<int> maximumWriteLength(String peripheralUuid) => _api.maximumWriteLength(peripheralUuid);

  @override
  Future<void> startRssiStreaming(String uuid) => _api.startRssiStreaming(uuid);

  @override
  Future<void> stopRssiStreaming(String uuid) => _api.stopRssiStreaming(uuid);

  @override
  Future<void> openBluetoothSettings() => _api.openBluetoothSettings();
}
