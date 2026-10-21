import 'dart:convert';
import 'dart:typed_data';

import 'package:caipo_app/core/errors/app_exception.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/mock_flobrain_interceptor.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The FloBrain shapes the app depends on, as FloBrain's backend code defines them
/// (checked on 21 Oct 2026). A change here must follow a change in FloBrain.
void main() {
  test('sign-in reads access_token and refresh_token', () async {
    final store = MemoryTokenStore();
    final adapter = _Recorder({
      '/api/auth/signin/': (200, '{"access_token":"a1","refresh_token":"r1","userId":"u1"}'),
    });
    final auth = AuthRepository(_api(store, adapter));

    final tokens = await auth.signIn(email: 'ada@example.com', password: 'secret');

    expect(tokens.accessToken, 'a1');
    expect(tokens.refreshToken, 'r1');
    expect((await store.read())!.refreshToken, 'r1');
    expect(adapter.bodies['/api/auth/signin/'], {'email': 'ada@example.com', 'password': 'secret'});
  });

  test('sign-in fails closed when a token field is missing', () async {
    final store = MemoryTokenStore();
    final adapter = _Recorder({'/api/auth/signin/': (200, '{"access":"a1","refresh":"r1"}')});
    final auth = AuthRepository(_api(store, adapter));

    await expectLater(
      auth.signIn(email: 'ada@example.com', password: 'secret'),
      throwsA(isA<ApiException>()),
    );
    expect(await store.read(), isNull);
  });

  test('sign-out sends refresh_token with the Bearer header, then clears the tokens', () async {
    final store = MemoryTokenStore();
    await store.write(const TokenPair(accessToken: 'a1', refreshToken: 'r1'));
    final adapter = _Recorder({'/api/auth/signout/': (200, '{"message":"Signed out"}')});
    final auth = AuthRepository(_api(store, adapter));

    await auth.signOut();

    expect(adapter.bodies['/api/auth/signout/'], {'refresh_token': 'r1'});
    expect(adapter.authorizations['/api/auth/signout/'], 'Bearer a1');
    expect(await store.read(), isNull);
  });

  test('sign-out without tokens does not call FloBrain', () async {
    final adapter = _Recorder({});
    await AuthRepository(_api(MemoryTokenStore(), adapter)).signOut();
    expect(adapter.bodies, isEmpty);
  });

  test('the reply is the last assistant message of the returned chat', () {
    final sent = {
      'id': 7,
      'title': 'CAIPO',
      'messages': [
        {'id': '1', 'role': 'user', 'text': 'first'},
        {'id': '2', 'role': 'assistant', 'text': 'old answer'},
        {'id': '3', 'role': 'user', 'text': 'second'},
        {'id': '4', 'role': 'assistant', 'text': ' new answer '},
      ],
      'usage': null,
    };
    expect(ChatRepository.replyFrom(sent), 'new answer');
    expect(ChatRepository.replyFrom({'reply': 'not a FloBrain field'}), isEmpty);
    expect(ChatRepository.replyFrom({'messages': []}), isEmpty);
  });

  test('the mock backend answers with the same shapes', () async {
    final api = FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true);
    final auth = AuthRepository(api);
    final chats = ChatRepository(api);
    await auth.signIn(email: 'ada@example.com', password: 'secret');
    final created = await chats.create({'title': 'CAIPO'});
    expect(created['messages'], isEmpty);

    final sent = await chats.send('${created['id']}', {'text': 'What is this?', 'image': 'aGVsbG8='});

    expect(ChatRepository.replyFrom(sent), contains(MockFloBrainInterceptor.cannedReply));
    expect(ChatRepository.replyFrom(sent), contains('picture'));
    await auth.signOut();
  });
}

FloBrainApi _api(TokenStore store, HttpClientAdapter adapter) {
  return FloBrainApi(
    tokenStore: store,
    logger: const AppLogger(),
    dio: Dio(BaseOptions(baseUrl: 'https://api.flobrain.ai'))..httpClientAdapter = adapter,
  );
}

class _Recorder implements HttpClientAdapter {
  _Recorder(this.routes);

  final Map<String, (int, String)> routes;
  final bodies = <String, Object?>{};
  final authorizations = <String, String?>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final data = options.data;
    bodies[path] = data is String ? jsonDecode(data) : data;
    authorizations[path] = options.headers['Authorization'] as String?;
    final (status, body) = routes[path] ?? (404, '{"error":"not found"}');
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
