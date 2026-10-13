/// Bluetooth SIG Battery Level characteristic: one uint8, percent.
int? parseBatteryLevel(List<int> bytes) {
  if (bytes.isEmpty) return null;
  final level = bytes.first & 0xFF;
  if (level > 100) return null;
  return level;
}
