/// STT is not in the published FloBrain API. This client returns no transcript.
class SttClient {
  const SttClient();

  Future<String?> transcribe(List<int> audio) async => null;
}

/// TTS is not in the published FloBrain API. This client returns no audio.
class TtsClient {
  const TtsClient();

  Future<List<int>> synthesize(String text) async => const [];
}
