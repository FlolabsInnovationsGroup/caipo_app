import 'dart:typed_data';

import 'package:caipo_app/device/audio/packet_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-time audio streaming is disabled', () {
    final assembler = PacketAssembler();
    expect(
      () => assembler.add(Uint8List.fromList([1, 0, 0, 9])),
      throwsA(isA<UnsupportedError>()),
    );
    expect(assembler.flush, throwsA(isA<UnsupportedError>()));
  });
}
