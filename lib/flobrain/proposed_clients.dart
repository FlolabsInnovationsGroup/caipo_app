import 'dart:typed_data';

import '../core/config/proposed_flags.dart';
import '../core/errors/app_exception.dart';
import '../device/audio/wav_pcm.dart';
import 'api_client.dart';
import 'speech_clients.dart';

/// Live STT and TTS for routes FloBrain has not published.
///
/// With the flag off these throw the same not-available errors as before.
class ProposedSpeechClient implements SpeechClient {
  ProposedSpeechClient(this._api, {this.enabled = kProposedSpeech});

  final FloBrainApi _api;
  final bool enabled;

  @override
  Future<String> transcribe(Uint8List pcm) async {
    if (!enabled) throw const SpeechUnavailable(UnavailableSpeechClient.sttMessage);
    if (pcm.length < 2) throw const SpeechUnavailable(UnavailableSpeechClient.sttMessage);
    final wav = writePcmWav(pcm);
    final response = await _api.send(
      'POST',
      '/api/speech/transcribe/',
      data: wav,
    );
    final body = response.data;
    final text = body is Map ? body['text'] : null;
    if (text is! String || text.isEmpty) {
      throw const SpeechUnavailable(UnavailableSpeechClient.sttMessage);
    }
    return text;
  }

  @override
  Future<Uint8List> synthesize(String text) async {
    if (!enabled) throw const SpeechUnavailable(UnavailableSpeechClient.ttsMessage);
    final response = await _api.send(
      'POST',
      '/api/speech/synthesize/',
      data: {'text': text, 'voice': 'default'},
    );
    final body = response.data;
    if (body is Uint8List && body.isNotEmpty) return body;
    if (body is List && body.isNotEmpty) return Uint8List.fromList(body.cast<int>());
    throw const SpeechUnavailable(UnavailableSpeechClient.ttsMessage);
  }
}

/// Photos and videos the Pi would upload. The routes do not exist yet.
class FloBrainMediaClient {
  FloBrainMediaClient(this._api, {this.enabled = kProposedMedia});

  static const unavailable = 'FloBrain media is not available.';

  final FloBrainApi _api;
  final bool enabled;

  Future<List<Map<String, dynamic>>> list() async {
    if (!enabled) throw const AppException(unavailable);
    final response = await _api.send('GET', '/api/media/');
    final data = response.data;
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (data is Map && data['results'] is List) {
      return [
        for (final item in data['results'] as List)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    return const [];
  }

  Future<Map<String, dynamic>> get(String id) async {
    if (!enabled) throw const AppException(unavailable);
    final response = await _api.send('GET', '/api/media/$id/');
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}

class HealthClient {
  HealthClient(this._api);

  final FloBrainApi _api;

  /// Public health check. No token is attached.
  Future<Map<String, dynamic>> check() async {
    final response = await _api.send('GET', '/api/dashboard/health/', authenticated: false);
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}
