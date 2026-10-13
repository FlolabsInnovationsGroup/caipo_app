import 'dart:typed_data';

import 'codec_negotiation.dart';

/// Inbound Opus decode is Phase 2 and is not implemented past the frame
/// contract. No PCM is produced.
class OpusDecodeResult {
  const OpusDecodeResult.unavailable({required this.codec, required this.reason})
      : pcm = null;

  final NegotiatedCodec codec;
  final Uint8List? pcm;
  final String reason;
}

class OpusDecoder {
  const OpusDecoder();

  OpusDecodeResult decode(Uint8List opusFrame, NegotiatedCodec codec) {
    return OpusDecodeResult.unavailable(
      codec: codec,
      reason:
          'Opus decode is not in this build. Expected '
          '${codec.frameSamples ?? 'unspecified'} samples at '
          '${codec.sampleRateHz} Hz.',
    );
  }
}
