import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class KnownDevice {
  const KnownDevice({
    required this.id,
    required this.name,
    this.batteryPercent,
    this.rssi,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final int? batteryPercent;
  final int? rssi;
  final DateTime lastSeen;

  KnownDevice copyWith({
    String? name,
    int? batteryPercent,
    int? rssi,
    DateTime? lastSeen,
  }) {
    return KnownDevice(
      id: id,
      name: name ?? this.name,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'batteryPercent': batteryPercent,
    'rssi': rssi,
    'lastSeen': lastSeen.toIso8601String(),
  };

  static KnownDevice? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final seen = DateTime.tryParse('${json['lastSeen']}') ?? DateTime.now();
    return KnownDevice(
      id: id,
      name: name,
      batteryPercent: json['batteryPercent'] as int?,
      rssi: json['rssi'] as int?,
      lastSeen: seen,
    );
  }
}

class KnownDeviceStore {
  KnownDeviceStore(this._preferences);

  static const storageKey = 'caipo.known_devices';

  final SharedPreferences _preferences;

  List<KnownDevice> load() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => KnownDevice.fromJson(Map<String, dynamic>.from(item)))
        .whereType<KnownDevice>()
        .toList();
  }

  Future<void> save(KnownDevice device) async {
    final devices = load().where((item) => item.id != device.id).toList()
      ..add(device);
    await _preferences.setString(
      storageKey,
      jsonEncode(devices.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final devices = load().where((item) => item.id != id).toList();
    await _preferences.setString(
      storageKey,
      jsonEncode(devices.map((item) => item.toJson()).toList()),
    );
  }
}
