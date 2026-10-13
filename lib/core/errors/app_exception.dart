class AppException implements Exception {
  const AppException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => details == null ? message : '$message ($details)';
}

class ApiException extends AppException {
  const ApiException(
    super.message, {
    required this.statusCode,
    super.details,
  });

  final int statusCode;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.details});
}

class SessionLockedException extends AppException {
  const SessionLockedException()
      : super('Session locked after a period of inactivity.');
}
