import '../../core/config/constants.dart';

/// R03 retry parameters that are specified: 3 attempts, 5 second authorisation
/// timeout, exponential backoff, resend the failed chunk only.
///
/// The spec does not give the backoff base. [delays] uses the only exponential
/// series the spec defines (R01's 1s, 2s, 4s). See NOTES.md.
class TransferRetryPolicy {
  const TransferRetryPolicy({
    this.maxAttempts = kTransferMaxAttempts,
    this.authorisationTimeout = kTransferAuthorisationTimeout,
    this.delays = kReconnectDelays,
  });

  final int maxAttempts;
  final Duration authorisationTimeout;
  final List<Duration> delays;

  /// Attempt indexes are zero-based. Returns null when the attempt budget
  /// is spent.
  Duration? delayBeforeAttempt(int attemptIndex) {
    if (attemptIndex < 0 || attemptIndex >= maxAttempts) return null;
    if (attemptIndex >= delays.length) return delays.last;
    return delays[attemptIndex];
  }

  bool shouldRetryChunk(int attemptsAlreadyMade) =>
      attemptsAlreadyMade < maxAttempts;
}
