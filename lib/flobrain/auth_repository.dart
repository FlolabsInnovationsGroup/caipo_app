import '../core/config/constants.dart';
import '../core/errors/app_exception.dart';
import 'api_client.dart';
import 'secure_token_store.dart';
import 'token_store.dart';

class AuthRepository {
  AuthRepository(this._api);

  final FloBrainApi _api;

  Future<TokenPair> register({required String email, required String password}) {
    return _authenticate('/api/auth/register/', email: email, password: password);
  }

  Future<TokenPair> signIn({required String email, required String password}) {
    return _authenticate('/api/auth/signin/', email: email, password: password);
  }

  Future<void> signOut() async {
    try {
      final tokens = await _api.tokenStore.read();
      // Nothing to revoke without a refresh token; FloBrain would answer 400.
      if (tokens == null) return;
      await _api.send(
        'POST',
        '/api/auth/signout/',
        data: {kSignOutRefreshField: tokens.refreshToken},
      );
    } finally {
      await _api.tokenStore.clear();
    }
  }

  Future<TokenPair?> restore() async {
    final existing = await _api.tokenStore.read();
    if (existing == null) return null;
    try {
      await _api.send('GET', '/api/profile/');
      return existing;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _api.tokenStore.clear();
        return null;
      }
      return existing;
    }
  }

  Future<TokenPair> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    final response = await _api.send(
      'POST',
      path,
      authenticated: false,
      data: {
        kEmailJsonField: email,
        kPasswordJsonField: password,
      },
    );
    final body = response.data;
    if (body is! Map) {
      throw ApiException(
        'Sign-in response was not an object.',
        statusCode: response.statusCode ?? 0,
      );
    }
    final tokens = tokenPairFromJson(Map<String, dynamic>.from(body));
    if (tokens == null) {
      throw ApiException(
        'Sign-in succeeded but the token fields "$kAccessTokenJsonField" and "$kRefreshTokenJsonField" were missing.',
        statusCode: response.statusCode ?? 200,
      );
    }
    await _api.tokenStore.write(tokens);
    return tokens;
  }
}
