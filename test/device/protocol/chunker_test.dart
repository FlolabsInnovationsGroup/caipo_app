import 'dart:typed_data';

import 'package:caipo_app/device/protocol/chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chunker = Chunker();

  test('empty input produces no chunks', () {
    expect(chunker.split(Uint8List(0)), isEmpty);
  });

  test('splits on 509-byte boundaries and numbers from zero', () {
    final data = Uint8List(510);
    for (var i = 0; i < data.length; i++) {
      data[i] = i & 0xFF;
    }
    final chunks = chunker.split(data);
    expect(chunks, hasLength(2));
    expect(chunks[0].sequence, 0);
    expect(chunks[0].payload, hasLength(509));
    expect(chunks[1].sequence, 1);
    expect(chunks[1].payload, hasLength(1));
    expect(chunks[1].payload.single, 509 & 0xFF);
  });

  test('an exact chunk stays in one piece', () {
    final chunks = chunker.split(Uint8List(509));
    expect(chunks, hasLength(1));
    expect(chunks.single.payload, hasLength(509));
  });

  test('rejects a transfer above 32 MB', () {
    expect(
      () => chunker.split(Uint8List(32 * 1024 * 1024 + 1)),
      throwsA(isA<TransferTooLarge>()),
    );
  });
}
