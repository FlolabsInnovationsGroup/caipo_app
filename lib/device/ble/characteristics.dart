import '../../core/config/constants.dart';

/// GATT map confirmed by the IoT team. UUID values live only in constants.dart.
class CaipoCharacteristics {
  const CaipoCharacteristics();

  String get primaryService => kPrimaryServiceUuid;

  /// Notify. Device to app, including R03 transfers.
  String get inbound => kInboundCharacteristicUuid;

  /// Read. Codec ID.
  String get audioCodec => kAudioCodecCharacteristicUuid;

  /// Write. App to device, including R03 transfers.
  String get outbound => kOutboundCharacteristicUuid;

  /// Notify and write. Heartbeat and non-transfer commands.
  String get commands => kCommandCharacteristicUuid;

  String get batteryService => kBatteryServiceUuid;
  String get batteryLevel => kBatteryLevelCharacteristicUuid;
  String get deviceInfoService => kDeviceInfoServiceUuid;
  String get modelNumber => kModelNumberCharacteristicUuid;
  String get serialNumber => kSerialNumberCharacteristicUuid;
  String get firmwareRevision => kFirmwareRevisionCharacteristicUuid;
  String get hardwareRevision => kHardwareRevisionCharacteristicUuid;
  String get manufacturerName => kManufacturerNameCharacteristicUuid;

  bool hasService(Iterable<String> serviceUuids, String expected) {
    final target = expected.toLowerCase();
    return serviceUuids.any((uuid) => uuid.toLowerCase() == target);
  }
}
