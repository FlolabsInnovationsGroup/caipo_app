import 'package:dio/dio.dart';

import '../core/config/constants.dart';

/// In-process FloBrain. It never opens a socket.
///
/// Field names match the placeholders the app already sends. They are not a
/// claim about the live API. Live mode does not use this class.
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
      final refresh = '${body[kRefreshTokenJsonField] ?? ''}';
      final account = _byRefresh(refresh);
      if (account == null) {
        handler.resolve(_json(options, 401, {'error': 'Refresh token was not recognised.', 'details': ''}));
        return;
      }
      handler.resolve(_json(options, 200, _tokens(account)));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/auth/signout/')) {
      handler.resolve(_json(options, 200, {'ok': true}));
      return;
    }

    if (method == 'GET' && path.endsWith('/api/dashboard/health/')) {
      handler.resolve(_json(options, 200, {'status': 'mock'}));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/speech/stt/')) {
      handler.resolve(_json(options, 200, {'text': cannedTranscript}));
      return;
    }

    if (method == 'POST' && path.endsWith('/api/speech/tts/')) {
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
      final text = '${body['text'] ?? body['message'] ?? ''}';
      history.add({'role': 'user', 'text': text});
      final reply = '$cannedReply You said: $text';
      history.add({'role': 'assistant', 'text': reply});
      handler.resolve(
        _json(options, 200, {
          'id': id,
          'reply': reply,
          'messages': history,
        }),
      );
      return;
    }

    if (method == 'POST' && path.endsWith('/api/brain/chats/')) {
      final id = '${_nextId++}';
      _chats[id] = [];
      handler.resolve(_json(options, 201, {'id': id}));
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
    return {kAccessTokenJsonField: account.access, kRefreshTokenJsonField: account.refresh};
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
