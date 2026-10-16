import 'package:flutter/services.dart';

import '../core/errors/app_exception.dart';
import '../device/audio/wav_pcm.dart';
import 'mock_flobrain_interceptor.dart';

/// Speech in and out of the voice loop.
///
/// Live FloBrain has no STT or TTS. Those calls fail with a clear error.
/// Mock mode returns a canned transcript and PCM from the bundled reply.
abstract class SpeechClient {
  Future<String> transcribe(Uint8List pcm);
  Future<Uint8List> synthesize(String text);
}

class UnavailableSpeechClient implements SpeechClient {
  const UnavailableSpeechClient();

  static const sttMessage = 'Speech to text is not available.';
  static const ttsMessage = 'Text to speech is not available.';

  @override
  Future<String> transcribe(Uint8List pcm) async {
    throw const SpeechUnavailable(sttMessage);
  }

  @override
  Future<Uint8List> synthesize(String text) async {
    throw const SpeechUnavailable(ttsMessage);
  }
}

class MockSpeechClient implements SpeechClient {
  const MockSpeechClient();

  @override
  Future<String> transcribe(Uint8List pcm) async {
    if (pcm.isEmpty) {
      throw const SpeechUnavailable(UnavailableSpeechClient.sttMessage);
    }
    return MockFloBrainInterceptor.cannedTranscript;
  }

  @override
  Future<Uint8List> synthesize(String text) async {
    if (text.trim().isEmpty) {
      throw const SpeechUnavailable(UnavailableSpeechClient.ttsMessage);
    }
    final data = await rootBundle.load('assets/sim/reply.wav');
    final wav = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return pcmBytes(toMono16k(parseWav(wav)));
  }
}

/// Live STT. FloBrain does not publish this route, so the call fails.
class SttClient {
  const SttClient();

  Future<String> transcribe(List<int> audio) async {
    throw const SpeechUnavailable(UnavailableSpeechClient.sttMessage);
  }
}

/// Live TTS. FloBrain does not publish this route, so the call fails.
class TtsClient {
  const TtsClient();

  Future<List<int>> synthesize(String text) async {
    throw const SpeechUnavailable(UnavailableSpeechClient.ttsMessage);
  }
}
