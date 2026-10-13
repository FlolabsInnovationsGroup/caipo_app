import '../../core/config/constants.dart';

/// Codec byte map from spec section 4.4, which follows OMI's shipping switch
/// and not OMI's published protocol document.
enum NegotiatedCodec {
  pcm8kHz(id: kCodecPcm8kHz, sampleRateHz: 8000, frameSamples: null),
  opus8kHz(id: kCodecOpus8kHz, sampleRateHz: 8000, frameSamples: 160),
  opus16kHz(id: kCodecOpus16kHz, sampleRateHz: 16000, frameSamples: 320);

  const NegotiatedCodec({
    required this.id,
    required this.sampleRateHz,
    required this.frameSamples,
  });

  final int id;
  final int sampleRateHz;

  /// Null for PCM, which the spec does not give a frame length for.
  final int? frameSamples;

  bool get isOpus => this == NegotiatedCodec.opus8kHz || this == NegotiatedCodec.opus16kHz;
}

class CodecNegotiation {
  const CodecNegotiation();

  /// Anything other than 1, 20 or 21 falls through to PCM 8 kHz.
  NegotiatedCodec fromByte(int codecByte) {
    switch (codecByte) {
      case kCodecPcm8kHz:
        return NegotiatedCodec.pcm8kHz;
      case kCodecOpus8kHz:
        return NegotiatedCodec.opus8kHz;
      case kCodecOpus16kHz:
        return NegotiatedCodec.opus16kHz;
      default:
        return NegotiatedCodec.pcm8kHz;
    }
  }

  /// Reads the first byte of the codec characteristic. An empty read falls
  /// through to PCM 8 kHz, matching OMI's shipping behaviour.
  NegotiatedCodec fromCharacteristic(List<int> bytes) {
    if (bytes.isEmpty) return NegotiatedCodec.pcm8kHz;
    return fromByte(bytes.first);
  }

  bool isTarget(NegotiatedCodec codec) => codec.id == kTargetCodecId;
}
