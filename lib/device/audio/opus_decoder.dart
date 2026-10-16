import 'dart:typed_data';

import 'codec_negotiation.dart';

/// The live decoder is [OpusCodec]. This type no longer reports success
/// without PCM.
class OpusDecodeResult {
  const OpusDecodeResult.unavailable({required this.codec, required this.reason}) : pcm = null;

  final NegotiatedCodec codec;
  final Uint8List? pcm;
  final String reason;
}

class OpusDecoder {
  const OpusDecoder();

  OpusDecodeResult decode(Uint8List opusFrame, NegotiatedCodec codec) {
    throw StateError(
      'Use OpusCodec. Opus decode is not available through this type '
      '(${codec.sampleRateHz} Hz).',
    );
  }
}
