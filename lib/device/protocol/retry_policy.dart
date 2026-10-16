import '../../core/config/constants.dart';

/// R03: wait 5 seconds, then retransmit only the failed chunk, up to 3 times.
///
/// [delays] is the R01 reconnect series. The transfer exchange does not use
/// it between chunk retransmits. It retransmits the named chunk as soon as
/// TRANSFER_ERROR arrives.
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
