import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/constants.dart';
import 'api_client.dart';

class SettingsRepository {
  SettingsRepository(this._api, this._preferences);

  static const autoLockKey = 'caipo.auto_lock_minutes';

  final FloBrainApi _api;
  final SharedPreferences _preferences;

  int autoLockMinutes() => _preferences.getInt(autoLockKey) ?? kDefaultAutoLockMinutes;

  Future<void> setAutoLockMinutes(int minutes) => _preferences.setInt(autoLockKey, minutes);

  Future<Map<String, dynamic>> preferences() async {
    return _object(await _api.send('GET', '/api/settings/preferences/'));
  }

  Future<Map<String, dynamic>> createPreferences(Map<String, dynamic> body) async {
    return _object(await _api.send('POST', '/api/settings/preferences/', data: body));
  }

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> patch) async {
    return _object(await _api.send('PATCH', '/api/settings/preferences/', data: patch));
  }

  Future<void> deletePreferences() async {
    await _api.send('DELETE', '/api/settings/preferences/');
  }

  Future<Map<String, dynamic>> presets() async {
    return _object(await _api.send('GET', '/api/settings/presets/'));
  }

  Map<String, dynamic> _object(dynamic response) {
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'results': data};
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const {};
  }
}
