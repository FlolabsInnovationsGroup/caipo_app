import 'package:dio/dio.dart';

import '../core/config/constants.dart';

/// In-process FloBrain. It never opens a socket.
///
/// Request and response shapes follow FloBrain's backend code (`users/views.py`,
/// `brain/views.py`, `brain/serializers.py`, checked on 21 Oct 2026), so tests
/// exercise the real contract. The speech routes are the proposed ones, which
/// FloBrain does not publish yet. Live mode does not use this class.
class MockFloBrainInterceptor extends Interceptor {
  final Map<String, _Account> _accounts = {};
  final Map<String, List<Map<String, dynamic>>> _chats = {};
  var _nextId = 1;

  static const cannedTranscript = 'This is a simulated transcript.';
  static const cannedReply = 'Simulated FloBrain reply.';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.uri.path;
    final method = options.method.toUpperCase();
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : <String, dynamic>{};
    final auth = options.headers['Authorization']?.toString() ?? '';
    final token = _bearer(auth);

    if (method == 'POST' && (path.endsWith('/api/auth/signin/') || path.endsWith('/api/auth/register/'))) {
      final email = '${body[kEmailJsonField] ?? ''}';
      final password = '${body[kPasswordJsonField] ?? ''}';
      if (email.isEmpty || password.isEmpty) {
        handler.resolve(_json(options, 400, {'error': 'Email and password are required.', 'details': ''}));
        return;
      }
      final account = _accounts.putIfAbsent(email, () => _Account(email));
      account.password = password;
      handler.resolve(_json(options, 200, _tokens(account)));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/auth/refresh/')) {
      final refresh = '${body[kRefreshRequestField] ?? ''}';
      final account = _byRefresh(refresh);
      if (account == null) {
        handler.resolve(_json(options, 401, {'error': 'Invalid or expired refresh token'}));
        return;
      }
      _tokens(account);
      // FloBrain answers with a new access token only.
      handler.resolve(_json(options, 200, {kRefreshResponseAccessField: account.access}));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/auth/signout/')) {
      if ('${body[kSignOutRefreshField] ?? ''}'.isEmpty) {
        handler.resolve(_json(options, 400, {'error': 'refresh_token is required'}));
        return;
      }
      handler.resolve(_json(options, 200, {'message': 'Signed out'}));
      return;
    }

    if (method == 'GET' && path.endsWith('/api/dashboard/health/')) {
      handler.resolve(_json(options, 200, {'status': 'mock'}));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/speech/transcribe/')) {
      handler.resolve(_json(options, 200, {'text': cannedTranscript}));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/speech/synthesize/')) {
      handler.resolve(_json(options, 200, {'audio': <int>[], 'text': '${body['text'] ?? ''}'}));
      return;
    }

    final account = _byAccess(token);
    if (account == null) {
      handler.resolve(_json(options, 401, {'error': 'Sign in required.', 'details': ''}));
      return;
    }

    if (method == 'GET' && path.endsWith('/api/profile/')) {
      handler.resolve(_json(options, 200, {'email': account.email}));
      return;
    }

    if (method == 'POST' && path.contains('/api/brain/chats/') && path.endsWith('/send/')) {
      final id = _chatId(path);
      final history = _chats.putIfAbsent(id, () => []);
      final text = '${body[kChatTextField] ?? ''}'.trim();
      final image = '${body[kChatImageField] ?? ''}';
      if (text.isEmpty && image.isEmpty) {
        handler.resolve(_json(options, 400, {'error': 'Validation failed', 'details': 'text or image required'}));
        return;
      }
      history.add(_message(history.length + 1, 'user', text, image: image));
      final seen = image.isEmpty ? '' : ' I looked at the picture you sent.';
      final reply = '$cannedReply You said: $text$seen';
      history.add(_message(history.length + 1, kChatAssistantRole, reply));
      handler.resolve(_json(options, 200, _chatDetail(id, history)));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/brain/chats/')) {
      final id = '${_nextId++}';
      _chats[id] = [];
      handler.resolve(_json(options, 201, _chatDetail(id, _chats[id]!)));
      return;
    }

    if (method == 'GET' && path.endsWith('/api/brain/chats/')) {
      handler.resolve(
        _json(options, 200, {
          'results': [for (final id in _chats.keys) {'id': id}],
        }),
      );
      return;
    }

    handler.resolve(_json(options, 200, {'ok': true}));
  }

  String _bearer(String header) {
    final prefix = '$kAuthorizationPrefix ';
    if (header.startsWith(prefix)) return header.substring(prefix.length);
    return '';
  }

  Map<String, String> _tokens(_Account account) {
    account.generation += 1;
    account.access = 'mock-access-${account.email}-${account.generation}';
    account.refresh = 'mock-refresh-${account.email}';
    return {
      kAccessTokenJsonField: account.access,
      kRefreshTokenJsonField: account.refresh,
      'userId': 'mock-user-${account.email}',
    };
  }

  Map<String, dynamic> _message(int id, String role, String text, {String image = ''}) {
    return {
      'id': '$id',
      kChatRoleField: role,
      kChatTextField: text,
      kChatImageField: image.isEmpty ? null : image,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _chatDetail(String id, List<Map<String, dynamic>> messages) {
    return {
      'id': int.tryParse(id) ?? id,
      'title': 'CAIPO',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      kChatMessagesField: messages,
      'usage': null,
    };
  }

  _Account? _byAccess(String token) {
    for (final account in _accounts.values) {
      if (account.access == token) return account;
    }
    return null;
  }

  _Account? _byRefresh(String token) {
    for (final account in _accounts.values) {
      if (account.refresh == token) return account;
    }
    return null;
  }

  String _chatId(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final chats = parts.indexOf('chats');
    if (chats >= 0 && chats + 1 < parts.length) return parts[chats + 1];
    return '1';
  }

  Response<Map<String, dynamic>> _json(RequestOptions options, int status, Map<String, dynamic> data) {
    return Response<Map<String, dynamic>>(requestOptions: options, statusCode: status, data: data);
  }
}

class _Account {
  _Account(this.email);

  final String email;
  String password = '';
  String access = '';
  String refresh = '';
  int generation = 0;
}
