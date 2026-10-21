import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/gen/secure_store_api.g.dart';

import 'token_store.dart';

/// iOS Keychain / Android Keystore via Pigeon. Not SharedPreferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._api);

  static const _accessKey = 'caipo.access_token';
  static const _refreshKey = 'caipo.refresh_token';

  final SecureStoreHostApi _api;

  @override
  Future<void> clear() async {
    await _api.delete(_accessKey);
    await _api.delete(_refreshKey);
  }

  /// Wipes every secret in the store, including history and media keys.
  Future<void> deleteAll() => _api.deleteAll();

  @override
  Future<TokenPair?> read() async {
    final access = await _api.read(_accessKey);
    final refresh = await _api.read(_refreshKey);
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      return null;
    }
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    await _api.write(_accessKey, tokens.accessToken);
    await _api.write(_refreshKey, tokens.refreshToken);
  }
}

/// Reads the sign-in token fields and fails closed when either is missing.
TokenPair? tokenPairFromJson(Map<String, dynamic> json) {
  final access = json[kAccessTokenJsonField];
  final refresh = json[kRefreshTokenJsonField];
  if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) {
    return null;
  }
  return TokenPair(accessToken: access, refreshToken: refresh);
}
