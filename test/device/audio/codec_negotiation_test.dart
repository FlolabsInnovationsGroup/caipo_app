import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/audio/codec_negotiation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const negotiation = CodecNegotiation();

  test('maps the three codec bytes from the shipping switch', () {
    expect(negotiation.fromByte(1), NegotiatedCodec.pcm8kHz);
    expect(negotiation.fromByte(20).sampleRateHz, 8000);
    expect(negotiation.fromByte(20).frameSamples, 160);
    expect(negotiation.fromByte(21), NegotiatedCodec.opus16kHz);
    expect(negotiation.fromByte(21).frameSamples, 320);
  });

  test('anything else falls through to PCM 8 kHz', () {
    expect(negotiation.fromByte(0), NegotiatedCodec.pcm8kHz);
    expect(negotiation.fromByte(10), NegotiatedCodec.pcm8kHz);
    expect(negotiation.fromByte(11), NegotiatedCodec.pcm8kHz);
    expect(negotiation.fromCharacteristic(const []), NegotiatedCodec.pcm8kHz);
  });

  test('the recommended target is codec 21', () {
    expect(kTargetCodecId, 21);
    expect(negotiation.isTarget(negotiation.fromByte(21)), isTrue);
    expect(negotiation.isTarget(negotiation.fromByte(20)), isFalse);
  });
}
