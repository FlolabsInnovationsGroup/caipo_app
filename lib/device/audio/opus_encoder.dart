import 'dart:typed_data';

/// Phase 4 mock. Returns no audio bytes and does not encode.
class OpusEncoder {
  const OpusEncoder();

  Uint8List encode(Uint8List pcm) => Uint8List(0);
}
