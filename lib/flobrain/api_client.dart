import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/config/constants.dart';
import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import 'mock_flobrain_interceptor.dart';
import 'token_store.dart';

class FloBrainApi {
  FloBrainApi({
    required TokenStore tokenStore,
    required AppLogger logger,
    Dio? dio,
    this.maxAttempts = kHttpMaxAttempts,
    this.mockBackend = false,
  }) : tokenStore = tokenStore,
       logger = logger,
       dio = dio ??
           Dio(
             BaseOptions(
               baseUrl: mockBackend ? 'http://mock.flobrain.local' : kFloBrainBaseUrl,
               connectTimeout: const Duration(seconds: kHttpTimeoutSeconds),
               receiveTimeout: const Duration(seconds: kHttpTimeoutSeconds),
               headers: const {'Accept': 'application/json'},
             ),
           ) {
    this.dio.options.validateStatus = (status) => status != null && status < 600;
    this.dio.interceptors.add(JwtInterceptor(tokenStore: tokenStore, dio: this.dio, logger: logger));
    if (mockBackend) {
      this.dio.interceptors.add(MockFloBrainInterceptor());
    }
  }

  final bool mockBackend;

  final TokenStore tokenStore;
  final AppLogger logger;
  final Dio dio;
  final int maxAttempts;

  Future<Response<dynamic>> send(
    String method,
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, dynamic>? query,
  }) {
    return _withRetry(() {
      return dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'authenticated': authenticated},
        ),
      );
    });
  }

  Future<Response<dynamic>> _withRetry(Future<Response<dynamic>> Function() send) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await send();
        final code = response.statusCode ?? 0;
        if (code == 429 || code >= 500) {
          lastError = ApiException(
            _message(response.data) ?? 'The server returned $code.',
            statusCode: code,
            details: _details(response.data),
          );
          if (attempt == maxAttempts - 1) throw lastError;
          await Future<void>.delayed(_backoff(response, attempt));
          continue;
        }
        if (code >= 400) {
          throw ApiException(
            _message(response.data) ?? 'Request failed ($code).',
            statusCode: code,
            details: _details(response.data),
          );
        }
        return response;
      } on DioException catch (error) {
        lastError = NetworkException(
          'The request to FloBrain timed out or failed.',
          details: error.message,
        );
        final retryable = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.connectionError;
        if (!retryable || attempt == maxAttempts - 1) {
          throw lastError;
        }
        logger.warn('Retrying FloBrain request after ${error.type.name}');
        await Future<void>.delayed(_backoff(null, attempt));
      }
    }
    throw lastError ?? const NetworkException('FloBrain request failed.');
  }

  Duration _backoff(Response<dynamic>? response, int attempt) {
    final header = response?.headers.value('retry-after');
    final seconds = int.tryParse(header ?? '');
    if (seconds != null && seconds > 0 && seconds < 120) {
      return Duration(seconds: seconds);
    }
    return Duration(milliseconds: min(8000, 500 * pow(2, attempt).toInt()));
  }

  static String? _message(Object? data) {
    if (data is Map && data[kApiErrorField] is String) {
      return data[kApiErrorField] as String;
    }
    return null;
  }

  static String? _details(Object? data) {
    if (data is Map && data[kApiDetailsField] != null) {
      return '${data[kApiDetailsField]}';
    }
    return null;
  }
}

class JwtInterceptor extends Interceptor {
  JwtInterceptor({
    required this.tokenStore,
    required this.dio,
    required this.logger,
  });

  final TokenStore tokenStore;
  final Dio dio;
  final AppLogger logger;
  Future<TokenPair?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final authenticated = options.extra['authenticated'] != false;
    if (authenticated && options.extra['skipAuth'] != true) {
      final tokens = await tokenStore.read();
      if (tokens != null && tokens.accessToken.isNotEmpty) {
        options.headers['Authorization'] = '$kAuthorizationPrefix ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    handler.next(err);
  }

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final code = response.statusCode ?? 0;
    final alreadyRetried = response.requestOptions.extra['retried'] == true;
    final skip = response.requestOptions.extra['skipAuth'] == true;
    if (code != 401 || alreadyRetried || skip) {
      handler.next(response);
      return;
    }
    try {
      final refreshed = await (_refreshing ??= _refresh());
      _refreshing = null;
      if (refreshed == null) {
        handler.next(response);
        return;
      }
      final request = response.requestOptions;
      request.extra['retried'] = true;
      request.headers['Authorization'] = '$kAuthorizationPrefix ${refreshed.accessToken}';
      final replay = await dio.fetch<dynamic>(request);
      handler.resolve(replay);
    } catch (error, stack) {
      _refreshing = null;
      logger.error('Token refresh failed', error: error, stackTrace: stack);
      await tokenStore.clear();
      handler.next(response);
    }
  }

  Future<TokenPair?> _refresh() async {
    final current = await tokenStore.read();
    if (current == null) return null;
    final response = await dio.post<dynamic>(
      '/api/auth/refresh/',
      data: {kRefreshRequestField: current.refreshToken},
      options: Options(
        extra: const {'skipAuth': true, 'authenticated': false},
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        'Session refresh failed.',
        statusCode: response.statusCode ?? 0,
      );
    }
    final body = response.data;
    if (body is! Map) {
      throw const ApiException('Refresh response was not an object.', statusCode: 200);
    }
    final access = body[kRefreshResponseAccessField];
    if (access is! String || access.isEmpty) {
      throw const ApiException(
        'Refresh response did not include the access token.',
        statusCode: 200,
      );
    }
    // FloBrain answers with a new access token only. Keep the refresh token we have,
    // unless a rotated one is present.
    final rotated = body[kRefreshRequestField] ?? body[kRefreshTokenJsonField];
    final merged = TokenPair(
      accessToken: access,
      refreshToken: rotated is String && rotated.isNotEmpty ? rotated : current.refreshToken,
    );
    await tokenStore.write(merged);
    return merged;
  }
}
