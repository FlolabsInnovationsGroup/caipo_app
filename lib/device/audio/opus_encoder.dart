import 'dart:typed_data';

/// The live encoder is [OpusCodec]. This type no longer returns empty audio.
class OpusEncoder {
  const OpusEncoder();

  Uint8List encode(Uint8List pcm) {
    throw StateError('Use OpusCodec. This encoder does not produce Opus.');
  }
}
