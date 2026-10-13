import 'dart:convert';

class DeviceInformation {
  const DeviceInformation({
    this.manufacturer,
    this.model,
    this.serial,
    this.firmware,
    this.hardware,
  });

  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? firmware;
  final String? hardware;
}

String? parseDeviceInfoString(List<int> bytes) {
  if (bytes.isEmpty) return null;
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  if (text.isEmpty) return null;
  return text.replaceAll('\u0000', '');
}
