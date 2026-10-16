import '../../core/config/constants.dart';

/// Any byte from the device counts as alive.
///
/// The 3-second silence rule is [kHeartbeatSilenceDisconnectEnabled]. It stays
/// off until the firmware sends heartbeats. While it is off, [silent] is
/// always false and the existing connection poll remains the disconnect signal.
class LinkLiveness {
  LinkLiveness({
    this.enabled = kHeartbeatSilenceDisconnectEnabled,
    this.silence = kHeartbeatSilenceTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final bool enabled;
  final Duration silence;
  final DateTime Function() _now;
  DateTime? _last;

  void arm() {
    _last = _now();
  }

  void mark() {
    _last = _now();
  }

  bool get silent {
    if (!enabled || _last == null) return false;
    return !_now().difference(_last!).isNegative && _now().difference(_last!) >= silence;
  }
}

class HeartbeatGap {
  const HeartbeatGap({required this.expected, required this.actual});

  final int expected;
  final int actual;
}

/// Tracks the uint8 heartbeat counter and reports a skipped value.
class HeartbeatTracker {
  int? _last;

  HeartbeatGap? note(int counter) {
    final previous = _last;
    _last = counter & 0xFF;
    if (previous == null) return null;
    final expected = (previous + 1) & 0xFF;
    if ((counter & 0xFF) == expected) return null;
    return HeartbeatGap(expected: expected, actual: counter & 0xFF);
  }
}
