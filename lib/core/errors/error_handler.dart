import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

void installErrorHandlers(AppLogger logger) {
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.error('Uncaught error', error: error, stackTrace: stack);
    return true;
  };
}

Future<T> guardAsync<T>(
  AppLogger logger,
  Future<T> Function() action, {
  required String context,
}) async {
  try {
    return await action();
  } catch (error, stack) {
    logger.error(context, error: error, stackTrace: stack);
    rethrow;
  }
}
