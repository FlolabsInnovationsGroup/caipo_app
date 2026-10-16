import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/ble/link_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the 3 second rule is off unless the flag is on', () {
    expect(kHeartbeatSilenceDisconnectEnabled, isFalse);
    var now = DateTime(2026);
    final off = LinkLiveness(now: () => now);
    off.arm();
    now = now.add(const Duration(seconds: 10));
    expect(off.silent, isFalse);

    final on = LinkLiveness(enabled: true, now: () => now);
    on.arm();
    expect(on.silent, isFalse);
    now = now.add(const Duration(seconds: 3));
    expect(on.silent, isTrue);
    on.mark();
    expect(on.silent, isFalse);
  });

  test('heartbeat counter gaps are reported and the silence flag stays off', () {
    expect(kHeartbeatSilenceDisconnectEnabled, isFalse);
    final tracker = HeartbeatTracker();
    expect(tracker.note(0), isNull);
    expect(tracker.note(1), isNull);
    final gap = tracker.note(4);
    expect(gap?.expected, 2);
    expect(gap?.actual, 4);
    expect(tracker.note(5), isNull);
  });
}
