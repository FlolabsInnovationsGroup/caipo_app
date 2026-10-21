import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/config/constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../flobrain/chat_repository.dart';
import 'history_store.dart';

enum PhotoQuestionPhase { idle, sending, done }

/// A photo and a typed question, answered by FloBrain.
///
/// This is the V1 "show it and ask" flow agreed with the IoT team on
/// 20 Oct 2026: a still picture plus a question, not a live stream. The photo
/// comes from the phone or from the last picture CAIPO sent.
class PhotoQuestionController extends ChangeNotifier {
  PhotoQuestionController({
    required this.chats,
    required this.history,
    required this.logger,
    required this.backendReadsImages,
  });

  final ChatRepository chats;
  final ConversationHistoryStore history;
  final AppLogger logger;

  /// False while FloBrain's chat view drops the image before the model.
  final bool backendReadsImages;

  PhotoQuestionPhase phase = PhotoQuestionPhase.idle;
  String? reply;
  String? alert;
  String? _chatId;
  var _generation = 0;

  static const blockedMessage =
      'FloBrain does not read photos yet. Its answer would ignore the picture, so photo questions are off.';

  bool get blocked => !backendReadsImages;

  /// The MIME type of [bytes], or null when it is not JPEG or PNG.
  static String? mimeOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return null;
  }

  static String dataUrl(Uint8List bytes, String mime) => 'data:$mime;base64,${base64Encode(bytes)}';

  Future<void> ask({required Uint8List photo, required String question}) async {
    final text = question.trim();
    alert = null;
    reply = null;
    if (blocked) {
      alert = blockedMessage;
      notifyListeners();
      return;
    }
    if (text.isEmpty) {
      alert = 'Type a question about the photo.';
      notifyListeners();
      return;
    }
    final mime = mimeOf(photo);
    if (mime == null) {
      alert = 'Only JPEG and PNG photos can be sent.';
      notifyListeners();
      return;
    }
    if (photo.length > kPhotoMaxBytes) {
      alert = 'The photo is larger than ${kPhotoMaxBytes ~/ (1024 * 1024)} MB.';
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    phase = PhotoQuestionPhase.sending;
    notifyListeners();
    try {
      final chatId = await _chat();
      final sent = await chats.send(chatId, {
        kChatTextField: text,
        kChatImageField: dataUrl(photo, mime),
      });
      if (generation != _generation) return;
      final answer = ChatRepository.replyFrom(sent);
      if (answer.isEmpty) throw const AppException('FloBrain returned no reply.');
      reply = answer;
      await history.append(role: 'user', text: '[Photo] $text');
      await history.append(role: 'assistant', text: answer);
      phase = PhotoQuestionPhase.done;
    } catch (error, stack) {
      if (generation != _generation) return;
      logger.error('Photo question failed', error: error, stackTrace: stack);
      alert = error is AppException ? error.message : 'The request failed. Try again.';
      phase = PhotoQuestionPhase.idle;
    }
    notifyListeners();
  }

  /// Stops waiting for the answer. FloBrain may still finish the request.
  void cancel() {
    if (phase != PhotoQuestionPhase.sending) return;
    _generation++;
    phase = PhotoQuestionPhase.idle;
    notifyListeners();
  }

  void reset() {
    _generation++;
    _chatId = null;
    reply = null;
    alert = null;
    phase = PhotoQuestionPhase.idle;
    notifyListeners();
  }

  Future<String> _chat() async {
    final existing = _chatId;
    if (existing != null) return existing;
    final created = await chats.create({'title': 'CAIPO photo'});
    final id = '${created['id'] ?? ''}';
    if (id.isEmpty) throw const AppException('FloBrain did not open a chat.');
    _chatId = id;
    return id;
  }
}
