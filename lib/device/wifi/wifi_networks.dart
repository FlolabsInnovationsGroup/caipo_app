import 'dart:convert';

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.password,
    this.phoneHotspot = false,
  });

  final String ssid;
  final String password;
  final bool phoneHotspot;

  WifiNetwork copyWith({String? ssid, String? password, bool? phoneHotspot}) {
    return WifiNetwork(
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      phoneHotspot: phoneHotspot ?? this.phoneHotspot,
    );
  }

  Map<String, Object?> toJson() => {
    'ssid': ssid,
    'password': password,
    'phoneHotspot': phoneHotspot,
  };

  static WifiNetwork? fromJson(Map<String, dynamic> json) {
    final ssid = json['ssid'];
    final password = json['password'];
    if (ssid is! String || ssid.isEmpty || password is! String) return null;
    return WifiNetwork(
      ssid: ssid,
      password: password,
      phoneHotspot: json['phoneHotspot'] == true,
    );
  }
}

/// Up to five saved networks, in priority order. The JSON is whatever the
/// caller persists. The app keeps it in the platform secure store.
class WifiNetworkStore {
  WifiNetworkStore({required this.read, required this.write});

  static const maxNetworks = 5;

  final Future<String?> Function() read;
  final Future<void> Function(String value) write;

  Future<List<WifiNetwork>> load() async {
    final raw = await read();
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => WifiNetwork.fromJson(Map<String, dynamic>.from(item)))
        .whereType<WifiNetwork>()
        .take(maxNetworks)
        .toList();
  }

  Future<List<WifiNetwork>> add(WifiNetwork network) async {
    final current = await load();
    if (current.length >= maxNetworks) {
      throw StateError('CAIPO keeps at most $maxNetworks Wi-Fi networks.');
    }
    final next = [...current, network];
    await _save(next);
    return next;
  }

  Future<List<WifiNetwork>> removeAt(int index) async {
    final current = await load();
    if (index < 0 || index >= current.length) return current;
    final next = [...current]..removeAt(index);
    await _save(next);
    return next;
  }

  Future<List<WifiNetwork>> move(int from, int to) async {
    final current = [...await load()];
    if (from < 0 || to < 0 || from >= current.length || to >= current.length) return current;
    final item = current.removeAt(from);
    current.insert(to, item);
    await _save(current);
    return current;
  }

  Future<void> _save(List<WifiNetwork> networks) {
    return write(jsonEncode([for (final network in networks.take(maxNetworks)) network.toJson()]));
  }
}
