import 'package:caipo_app/device/ble/pairing_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every pairing failure has its own actionable message', () {
    final titles = PairingFailure.values.map((failure) => failure.title).toSet();
    expect(titles, hasLength(PairingFailure.values.length));
    for (final failure in PairingFailure.values) {
      expect(failure.message.trim(), isNotEmpty);
    }
  });
}
