import '../../core/config/constants.dart';

/// Codec byte on the read characteristic.
///
/// CAIPO recordings and AI replies are Opus 16 kHz, codec 21. Bytes 1 and 20
/// are recognised and are not the recording format. Any other byte is
/// unsupported.
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

  /// Null when the byte is not 1, 20 or 21.
  NegotiatedCodec? fromByte(int codecByte) {
    switch (codecByte) {
      case kCodecPcm8kHz:
        return NegotiatedCodec.pcm8kHz;
      case kCodecOpus8kHz:
        return NegotiatedCodec.opus8kHz;
      case kCodecOpus16kHz:
        return NegotiatedCodec.opus16kHz;
      default:
        return null;
    }
  }

  /// Reads the first byte of the codec characteristic. An empty read is
  /// unsupported.
  NegotiatedCodec? fromCharacteristic(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return fromByte(bytes.first);
  }

  bool isTarget(NegotiatedCodec codec) => codec.id == kTargetCodecId;
}
