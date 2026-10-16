import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/core/errors/app_exception.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:caipo_app/device/audio/wav_pcm.dart';
import 'package:caipo_app/device/ble/connection.dart';
import 'package:caipo_app/device/protocol/device_transfer_session.dart';
import 'package:caipo_app/device/protocol/transfer_archive.dart';
import 'package:caipo_app/device/sim/sim_caipo_controller.dart';
import 'package:caipo_app/core/security/secret_store.dart';
import 'package:caipo_app/features/conversation/history_store.dart';
import 'package:caipo_app/features/conversation/voice_loop.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/mock_flobrain_interceptor.dart';
import 'package:caipo_app/flobrain/speech_clients.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/load_opus.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadOpusForTests();
  });

  test('live speech fails with a clear not-available error', () {
    const speech = UnavailableSpeechClient();
    expect(
      speech.transcribe(Uint8List.fromList([1, 0])),
      throwsA(
        isA<SpeechUnavailable>().having(
          (error) => error.message,
          'message',
          'Speech to text is not available.',
        ),
      ),
    );
    expect(
      speech.synthesize('hello'),
      throwsA(
        isA<SpeechUnavailable>().having(
          (error) => error.message,
          'message',
          'Text to speech is not available.',
        ),
      ),
    );
    expect(const SttClient().transcribe(const [1]), throwsA(isA<SpeechUnavailable>()));
    expect(const TtsClient().synthesize('hello'), throwsA(isA<SpeechUnavailable>()));
  });

  test('sim and mock run the voice loop and store encrypted history', () async {
    final replies = await Directory.systemTemp.createTemp('caipo-replies');
    final saved = await Directory.systemTemp.createTemp('caipo-transfers');
    final historyDir = await Directory.systemTemp.createTemp('caipo-history');
    final bridge = SimCaipoController.open(replyDirectory: replies);
    final connection = DeviceConnection(bridge, const AppLogger());
    final api = FloBrainApi(
      tokenStore: MemoryTokenStore(),
      logger: const AppLogger(),
      mockBackend: true,
    );
    await AuthRepository(api).signIn(email: 'ada@example.com', password: 'secret');
    final history = ConversationHistoryStore(directory: historyDir, secrets: SecretStore.memory());
    final voice = VoiceLoopController(
      connection: connection,
      bridge: bridge,
      chats: ChatRepository(api),
      speech: const MockSpeechClient(),
      archive: TransferArchive(saved),
      history: history,
      logger: const AppLogger(),
      idleTimeout: const Duration(minutes: 5),
    );
    final transfers = DeviceTransferSession(
      deviceId: SimCaipoController.deviceId,
      connection: connection,
      events: bridge.characteristicValues.stream,
      logger: const AppLogger(),
      onTransferStarted: voice.markListening,
      onCompleted: (payload, type) {
        return voice.acceptTransfer(
          SimCaipoController.deviceId,
          payload,
          type,
          codecSupported: true,
        );
      },
    )..start();

    await connection.connect(SimCaipoController.deviceId);
    final finished = DateTime.now().add(const Duration(seconds: 30));
    while (voice.phase != VoicePhase.done) {
      if (voice.alert != null) fail(voice.alert!);
      if (DateTime.now().isAfter(finished)) {
        fail('Voice loop stayed at ${voice.phase.name}.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(voice.transcript, MockFloBrainInterceptor.cannedTranscript);
    expect(voice.replyText, contains(MockFloBrainInterceptor.cannedReply));
    expect(voice.label, 'Done');

    final wavs = replies.listSync().whereType<File>().where((file) => file.path.endsWith('.wav')).toList();
    expect(wavs, hasLength(1));
    final wav = parseWav(await wavs.single.readAsBytes());
    expect(wav.sampleRate, 16000);
    expect(wav.samples, isNotEmpty);

    final archived = saved.listSync().whereType<File>().toList();
    expect(archived, hasLength(1));
    expect(archived.single.path, contains('_type${kContentTypeAudio}_'));
    expect(archived.single.path, contains('_${await archived.single.length()}.bin'));

    final stored = await history.load();
    expect(stored.map((entry) => entry['text']), contains(MockFloBrainInterceptor.cannedTranscript));
    final cipher = await File('${historyDir.path}${Platform.pathSeparator}history.bin').readAsBytes();
    expect(String.fromCharCodes(cipher), isNot(contains(MockFloBrainInterceptor.cannedTranscript)));

    voice.endSession();
    expect(voice.phase, VoicePhase.idle);
    expect(voice.sessionOpen, isFalse);

    await transfers.stop();
    await replies.delete(recursive: true);
    await saved.delete(recursive: true);
    await historyDir.delete(recursive: true);
  });

  test('a running voice request can be cancelled', () async {
    final saved = await Directory.systemTemp.createTemp('caipo-cancel');
    final historyDir = await Directory.systemTemp.createTemp('caipo-cancel-history');
    final bridge = SimCaipoController.open();
    final hold = _HoldSpeech();
    final voice = VoiceLoopController(
      connection: DeviceConnection(bridge, const AppLogger()),
      bridge: bridge,
      chats: ChatRepository(
        FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true),
      ),
      speech: hold,
      archive: TransferArchive(saved),
      history: ConversationHistoryStore(directory: historyDir, secrets: SecretStore.memory()),
      logger: const AppLogger(),
    );
    final tone = Int16List(kOpusFrameSamples);
    tone[0] = 400;
    final pending = voice.acceptTransfer(
      'device',
      OpusCodec.shared.encodeSamples(tone),
      kContentTypeAudio,
      codecSupported: true,
    );
    await hold.started.future;
    expect(voice.phase, VoicePhase.processing);
    voice.cancel();
    hold.release();
    await pending;
    expect(voice.phase, VoicePhase.idle);
    expect(voice.replyText, isNull);
    await saved.delete(recursive: true);
    await historyDir.delete(recursive: true);
  });

  test('a failed turn keeps the recording as not sent', () async {
    final saved = await Directory.systemTemp.createTemp('caipo-unsent');
    final historyDir = await Directory.systemTemp.createTemp('caipo-unsent-history');
    final history = ConversationHistoryStore(directory: historyDir, secrets: SecretStore.memory());
    final bridge = SimCaipoController.open();
    final voice = VoiceLoopController(
      connection: DeviceConnection(bridge, const AppLogger()),
      bridge: bridge,
      chats: ChatRepository(
        FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true),
      ),
      speech: const UnavailableSpeechClient(),
      archive: TransferArchive(saved),
      history: history,
      logger: const AppLogger(),
    );
    final tone = Int16List(kOpusFrameSamples);
    tone[0] = 400;
    await voice.acceptTransfer(
      'device',
      OpusCodec.shared.encodeSamples(tone),
      kContentTypeAudio,
      codecSupported: true,
    );
    expect(voice.alert, UnavailableSpeechClient.sttMessage);
    final stored = await history.load();
    expect(stored.single['status'], 'not_sent');
    final name = stored.single['recording'] as String;
    final restored = await history.readRecording(name);
    expect(restored, isNotEmpty);
    await saved.delete(recursive: true);
    await historyDir.delete(recursive: true);
  });
}

class _HoldSpeech implements SpeechClient {
  final Completer<void> started = Completer<void>();
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<String> transcribe(Uint8List pcm) {
    if (!started.isCompleted) started.complete();
    return _gate.future.then((_) => 'held');
  }

  @override
  Future<Uint8List> synthesize(String text) async => Uint8List(kOpusFrameSamples * 2);
}
