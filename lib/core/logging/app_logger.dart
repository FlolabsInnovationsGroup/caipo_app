import 'dart:developer' as developer;

class AppLogger {
  const AppLogger({this.name = 'caipo'});

  final String name;

  void debug(String message) => _write(message, 500);

  void info(String message) => _write(message, 800);

  void warn(String message) => _write(message, 900);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  void _write(String message, int level) {
    developer.log(message, name: name, level: level);
  }
}
