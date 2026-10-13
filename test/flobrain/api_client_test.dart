import 'dart:typed_data';

import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attaches the bearer token and refreshes once on 401', () async {
    final store = MemoryTokenStore();
    await store.write(const TokenPair(accessToken: 'old-access', refreshToken: 'refresh-1'));
    final adapter = _ScriptedAdapter([
      _Script(status: 401, body: '{"error":"expired"}'),
      _Script(status: 200, body: '{"access":"new-access","refresh":"refresh-2"}', matchPath: '/api/auth/refresh/'),
      _Script(status: 200, body: '{"ok":true}'),
    ]);
    final api = FloBrainApi(
      tokenStore: store,
      logger: const AppLogger(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.flobrain.ai'))..httpClientAdapter = adapter,
    );

    final response = await api.send('GET', '/api/profile/');

    expect(response.statusCode, 200);
    expect(adapter.authorizations, ['Bearer old-access', 'Bearer new-access']);
    expect((await store.read())!.accessToken, 'new-access');
    expect(adapter.refreshBodies.single, contains('refresh-1'));
  });

  test('retries a 500 and then surfaces the documented error', () async {
    final store = MemoryTokenStore();
    final adapter = _ScriptedAdapter([
      _Script(status: 500, body: '{"error":"unavailable","details":"db"}'),
      _Script(status: 500, body: '{"error":"unavailable","details":"db"}'),
      _Script(status: 500, body: '{"error":"unavailable","details":"db"}'),
    ]);
    final api = FloBrainApi(
      tokenStore: store,
      logger: const AppLogger(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.flobrain.ai', connectTimeout: const Duration(seconds: 1)))
        ..httpClientAdapter = adapter,
    );

    await expectLater(
      api.send('GET', '/api/dashboard/health/', authenticated: false),
      throwsA(predicate((error) => '$error'.contains('unavailable'))),
    );
    expect(adapter.hits, 3);
  });
}

class _Script {
  const _Script({required this.status, required this.body, this.matchPath});
  final int status;
  final String body;
  final String? matchPath;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.scripts);
  final List<_Script> scripts;
  final authorizations = <String>[];
  final refreshBodies = <String>[];
  var hits = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    hits += 1;
    final auth = options.headers['Authorization'];
    if (auth is String) authorizations.add(auth);
    if (options.uri.path.endsWith('/api/auth/refresh/') && options.data != null) {
      refreshBodies.add('${options.data}');
    }
    final script = scripts.removeAt(0);
    if (script.matchPath != null) {
      expect(options.uri.path, endsWith(script.matchPath!));
    }
    return ResponseBody.fromString(
      script.body,
      script.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
