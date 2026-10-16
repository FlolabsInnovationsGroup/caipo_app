import 'package:pigeon/pigeon.dart';

/// Pigeon contract for the CAIPO BLE stack.
///
/// Adapted from OMI's BleHostApi / BleFlutterApi (MIT, BasedHardware/Omi).
/// Watch, Ray-Ban, and continuous-capture APIs are intentionally absent.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/gen/ble_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/BleApi.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut: 'android/app/src/main/kotlin/com/flolabs/caipo/BleApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.flolabs.caipo'),
  ),
)
class BlePeripheral {
  BlePeripheral({
    required this.uuid,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });

  final String uuid;
  final String name;
  final int rssi;
  final List<String> serviceUuids;
}

class BleService {
  BleService({required this.uuid, required this.characteristicUuids});

  final String uuid;
  final List<String> characteristicUuids;
}

@HostApi()
abstract class BleHostApi {
  void startScan(int timeoutSeconds, List<String> serviceUuids);
  void stopScan();
  void manageDevice(String uuid, bool requiresBond);
  void unmanageDevice(String uuid);

  @async
  bool requestBond(String uuid);

  @async
  Uint8List readCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );

  @async
  void writeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data,
  );

  @async
  void subscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );

  void unsubscribeCharacteristic(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
  );

  String getBluetoothState();

  @async
  bool enableBluetooth();

  bool isPeripheralConnected(String uuid);

  /// Largest with-response write, in bytes.
  ///
  /// iOS returns `maximumWriteValueLength(for: .withResponse)`. Android
  /// returns the negotiated ATT payload (`mtu - 3`). The app does not ask
  /// iOS for an MTU.
  @async
  int maximumWriteLength(String peripheralUuid);

  void startRssiStreaming(String uuid);
  void stopRssiStreaming(String uuid);

  /// Opens the system Bluetooth settings page. iOS opens the app's Settings
  /// page because iOS does not allow a direct jump to the Bluetooth toggle.
  void openBluetoothSettings();
}

@FlutterApi()
abstract class BleFlutterApi {
  void onBluetoothStateChanged(String state);
  void onPeripheralDiscovered(BlePeripheral peripheral);
  void onDeviceReady(String peripheralUuid, List<BleService> services);
  void onPeripheralDisconnected(String peripheralUuid, String? error);
  void onCharacteristicValueUpdated(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List value,
  );
  void onRssiUpdate(String peripheralUuid, int rssi);
  void onStateRestored(List<String> peripheralUuids);
}
