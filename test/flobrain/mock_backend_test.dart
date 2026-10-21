import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/mock_flobrain_interceptor.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock backend signs in and keeps chat context without a network', () async {
    final api = FloBrainApi(
      tokenStore: MemoryTokenStore(),
      logger: const AppLogger(),
      mockBackend: true,
    );
    final auth = AuthRepository(api);
    final chat = ChatRepository(api);

    final tokens = await auth.signIn(email: 'ada@example.com', password: 'secret');
    expect(tokens.accessToken, startsWith('mock-access-'));

    final created = await chat.create({'title': 'First'});
    final sent = await chat.send('${created['id']}', {'text': 'hello'});
    expect(ChatRepository.replyFrom(sent), contains(MockFloBrainInterceptor.cannedReply));
    expect(ChatRepository.replyFrom(sent), contains('hello'));
    expect((sent['messages'] as List), hasLength(2));

    final speech = await api.send('POST', '/api/speech/transcribe/', data: {'audio': <int>[]});
    expect(speech.data['text'], MockFloBrainInterceptor.cannedTranscript);
  });
}
