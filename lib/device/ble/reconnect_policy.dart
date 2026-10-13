import '../../core/config/constants.dart';

/// R01.4: after a link loss, wait 1s, then 2s, then 4s.
class ReconnectPolicy {
  const ReconnectPolicy({this.delays = kReconnectDelays});

  final List<Duration> delays;

  int get maxAttempts => delays.length;

  Duration? delayForAttempt(int attemptIndex) {
    if (attemptIndex < 0 || attemptIndex >= delays.length) return null;
    return delays[attemptIndex];
  }
}
