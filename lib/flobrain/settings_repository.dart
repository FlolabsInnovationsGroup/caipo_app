import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/constants.dart';
import 'api_client.dart';

class SettingsRepository {
  SettingsRepository(this._api, this._preferences);

  static const autoLockKey = 'caipo.auto_lock_minutes';
  static const autoConnectKey = 'caipo.auto_connect';
  static const voiceKey = 'caipo.ai_voice';
  static const languageKey = 'caipo.ai_language';
  static const biometricKey = 'caipo.biometric_unlock';
  static const minAutoLockMinutes = 1;
  static const maxAutoLockMinutes = 30;
  static const voices = ['Default', 'Clear', 'Warm'];
  static const languages = ['English', 'Arabic'];

  final FloBrainApi _api;
  final SharedPreferences _preferences;

  int autoLockMinutes() {
    final stored = _preferences.getInt(autoLockKey) ?? kDefaultAutoLockMinutes;
    return stored.clamp(minAutoLockMinutes, maxAutoLockMinutes);
  }

  Future<void> setAutoLockMinutes(int minutes) {
    final clamped = minutes.clamp(minAutoLockMinutes, maxAutoLockMinutes);
    return _preferences.setInt(autoLockKey, clamped);
  }

  bool autoConnect() => _preferences.getBool(autoConnectKey) ?? true;

  Future<void> setAutoConnect(bool value) => _preferences.setBool(autoConnectKey, value);

  /// The 16 Oct 2026 schema for `/api/settings/preferences/` defines no voice
  /// or language fields, so these stay on the phone.
  String aiVoice() {
    final stored = _preferences.getString(voiceKey);
    return voices.contains(stored) ? stored! : voices.first;
  }

  Future<void> setAiVoice(String value) => _preferences.setString(voiceKey, value);

  String aiLanguage() {
    final stored = _preferences.getString(languageKey);
    return languages.contains(stored) ? stored! : languages.first;
  }

  Future<void> setAiLanguage(String value) => _preferences.setString(languageKey, value);

  bool biometricUnlock() => _preferences.getBool(biometricKey) ?? false;

  Future<void> setBiometricUnlock(bool value) => _preferences.setBool(biometricKey, value);

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
