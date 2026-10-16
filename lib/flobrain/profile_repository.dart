import '../core/config/constants.dart';
import 'api_client.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final FloBrainApi _api;

  Future<Map<String, dynamic>> get() async => _object(await _api.send('GET', '/api/profile/'));

  Future<Map<String, dynamic>> update(Map<String, dynamic> patch) async {
    return _object(await _api.send('PATCH', '/api/profile/', data: patch));
  }

  /// Field names are TBD. See constants.dart.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.send(
      'POST',
      '/api/profile/change-password/',
      data: {
        kCurrentPasswordJsonField: currentPassword,
        kNewPasswordJsonField: newPassword,
      },
    );
  }

  Future<void> deleteAccount({required String password}) async {
    await _api.send(
      'POST',
      '/api/profile/delete/',
      data: {kPasswordJsonField: password},
    );
    await _api.tokenStore.clear();
  }

  Map<String, dynamic> _object(dynamic response) {
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}
