import 'dart:developer' as developer;

class AppLogger {
  const AppLogger({this.name = 'caipo'});

  static const maxLines = 300;

  /// Recent lines for the diagnostics screen. Shared by every logger.
  static final List<String> lines = [];

  final String name;

  void debug(String message) => _write('debug', message, 500);

  void info(String message) => _write('info', message, 800);

  void warn(String message) => _write('warn', message, 900);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _remember('error', message);
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  void _write(String levelName, String message, int level) {
    _remember(levelName, message);
    developer.log(message, name: name, level: level);
  }

  void _remember(String levelName, String message) {
    lines.add('${DateTime.now().toIso8601String()} $levelName $message');
    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
  }
}
