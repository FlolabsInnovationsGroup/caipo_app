/// Image input, video input, custom system prompts, and offline AI.
///
/// The 16 Oct 2026 FloBrain schema does not define these. The methods fail
/// closed. They are not sent.
class AdvancedAiClient {
  const AdvancedAiClient();

  static const unavailable = 'Not available. The FloBrain schema does not define this.';

  Future<void> sendImage(List<int> bytes) async {
    throw StateError(unavailable);
  }

  Future<void> sendVideo(List<int> bytes) async {
    throw StateError(unavailable);
  }

  Future<void> setSystemPrompt(String prompt) async {
    throw StateError(unavailable);
  }

  Future<void> replyOffline(String text) async {
    throw StateError(unavailable);
  }
}
