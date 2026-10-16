import 'dart:typed_data';

import 'package:caipo_app/device/audio/opus_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const container = OpusFrameContainer();

  test('packs and unpacks length-prefixed Opus frames', () {
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([9]);
    final packed = container.pack([first, second]);
    expect(packed, [3, 0, 1, 2, 3, 1, 0, 9]);
    final frames = container.unpack(packed);
    expect(frames, hasLength(2));
    expect(frames[0], first);
    expect(frames[1], second);
  });

  test('an empty recording packs to an empty payload', () {
    expect(container.pack(const []), isEmpty);
    expect(container.unpack(Uint8List(0)), isEmpty);
  });

  test('a truncated frame is rejected', () {
    expect(
      () => container.unpack(Uint8List.fromList([2, 0, 1])),
      throwsFormatException,
    );
  });
}
