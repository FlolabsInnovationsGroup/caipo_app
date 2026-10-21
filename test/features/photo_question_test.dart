import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/core/security/secret_store.dart';
import 'package:caipo_app/device/protocol/transfer_archive.dart';
import 'package:caipo_app/features/conversation/history_store.dart';
import 'package:caipo_app/features/conversation/photo_question.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/mock_flobrain_interceptor.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 0xFF, 0xD9]);

Future<(PhotoQuestionController, ConversationHistoryStore)> _controller({required bool readsImages}) async {
  final api = FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true);
  await AuthRepository(api).signIn(email: 'ada@example.com', password: 'secret');
  final dir = await Directory.systemTemp.createTemp('caipo-photo-history');
  final history = ConversationHistoryStore(directory: dir, secrets: SecretStore.memory());
  final controller = PhotoQuestionController(
    chats: ChatRepository(api),
    history: history,
    logger: const AppLogger(),
    backendReadsImages: readsImages,
  );
  return (controller, history);
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('a photo and a question reach FloBrain and the answer is kept', () async {
    final (photo, history) = await _controller(readsImages: true);

    await photo.ask(photo: _jpeg, question: '  What is this?  ');

    expect(photo.alert, isNull);
    expect(photo.phase, PhotoQuestionPhase.done);
    expect(photo.reply, contains(MockFloBrainInterceptor.cannedReply));
    expect(photo.reply, contains('picture'));
    final entries = await history.load();
    expect(entries.map((entry) => entry['role']), ['user', 'assistant']);
    expect(entries.first['text'], '[Photo] What is this?');
  });

  test('live FloBrain that drops the image blocks the question', () async {
    final (photo, history) = await _controller(readsImages: false);

    await photo.ask(photo: _jpeg, question: 'What is this?');

    expect(photo.blocked, isTrue);
    expect(photo.alert, PhotoQuestionController.blockedMessage);
    expect(photo.reply, isNull);
    expect(await history.load(), isEmpty);
  });

  test('empty questions, unknown formats and oversized photos are refused before sending', () async {
    final (photo, history) = await _controller(readsImages: true);

    await photo.ask(photo: _jpeg, question: '   ');
    expect(photo.alert, 'Type a question about the photo.');

    await photo.ask(photo: Uint8List.fromList([1, 2, 3, 4, 5]), question: 'What is this?');
    expect(photo.alert, 'Only JPEG and PNG photos can be sent.');

    final big = Uint8List(kPhotoMaxBytes + 1)..setAll(0, [0xFF, 0xD8, 0xFF]);
    await photo.ask(photo: big, question: 'What is this?');
    expect(photo.alert, contains('larger than'));

    expect(await history.load(), isEmpty);
  });

  test('the photo goes out as a data URL', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);
    expect(PhotoQuestionController.mimeOf(_jpeg), 'image/jpeg');
    expect(PhotoQuestionController.mimeOf(png), 'image/png');
    expect(PhotoQuestionController.dataUrl(_jpeg, 'image/jpeg'), 'data:image/jpeg;base64,${base64Encode(_jpeg)}');
  });

  test('the archive finds the newest photo CAIPO sent', () async {
    final dir = await Directory.systemTemp.createTemp('caipo-photo-archive');
    final archive = TransferArchive(dir);
    expect(archive.latest(kContentTypeImage), isNull);
    await archive.save(bytes: Uint8List.fromList([1]), contentType: kContentTypeAudio);
    await archive.save(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]), contentType: kContentTypeImage);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await archive.save(bytes: _jpeg, contentType: kContentTypeImage);

    final latest = archive.latest(kContentTypeImage);

    expect(latest, isNotNull);
    expect(await archive.read(latest!), _jpeg);
  });
}
