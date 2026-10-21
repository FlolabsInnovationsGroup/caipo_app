import 'package:dio/dio.dart';
import '../core/config/constants.dart';
import 'api_client.dart';

class ChatRepository {
  ChatRepository(this._api);

  final FloBrainApi _api;

  Future<Map<String, dynamic>> list() async => _object(await _api.send('GET', '/api/brain/chats/'));

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    return _object(await _api.send('POST', '/api/brain/chats/', data: body));
  }

  Future<Map<String, dynamic>> get(String chatId) async {
    return _object(await _api.send('GET', '/api/brain/chats/$chatId/'));
  }

  Future<Map<String, dynamic>> update(String chatId, Map<String, dynamic> patch) async {
    return _object(await _api.send('PATCH', '/api/brain/chats/$chatId/', data: patch));
  }

  Future<void> delete(String chatId) async {
    await _api.send('DELETE', '/api/brain/chats/$chatId/');
  }

  Future<Map<String, dynamic>> send(String chatId, Map<String, dynamic> message, {CancelToken? cancelToken}) async {
    return _object(
      await _api.send('POST', '/api/brain/chats/$chatId/send/', data: message, cancelToken: cancelToken),
    );
  }

  /// The assistant's answer in a send response: the text of the last message whose
  /// role is `assistant`. Empty when the body has no such message (live mode then
  /// fails closed instead of inventing a reply).
  static String replyFrom(Map<String, dynamic> sent) {
    final messages = sent[kChatMessagesField];
    if (messages is! List) return '';
    for (final message in messages.reversed) {
      if (message is Map && message[kChatRoleField] == kChatAssistantRole) {
        return '${message[kChatTextField] ?? ''}'.trim();
      }
    }
    return '';
  }

  Map<String, dynamic> _object(dynamic response) {
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'results': data};
    return const {};
  }
}
