import '../../core/config/constants.dart';

/// Logical GATT map. UUID values live only in constants.dart.
class CaipoCharacteristics {
  const CaipoCharacteristics();

  String get primaryService => kPrimaryServiceUuid;
  String get audioNotify => kAudioNotifyCharacteristicUuid;
  String get audioCodec => kAudioCodecCharacteristicUuid;
  String get outboundAudio => kOutboundAudioCharacteristicUuid;
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
