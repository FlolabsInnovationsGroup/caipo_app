import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/audio/codec_negotiation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const negotiation = CodecNegotiation();

  test('maps the known codec bytes', () {
    expect(negotiation.fromByte(1), NegotiatedCodec.pcm8kHz);
    expect(negotiation.fromByte(20)!.sampleRateHz, 8000);
    expect(negotiation.fromByte(20)!.frameSamples, 160);
    expect(negotiation.fromByte(21), NegotiatedCodec.opus16kHz);
    expect(negotiation.fromByte(21)!.frameSamples, 320);
  });

  test('anything else is unsupported', () {
    expect(negotiation.fromByte(0), isNull);
    expect(negotiation.fromByte(10), isNull);
    expect(negotiation.fromByte(11), isNull);
    expect(negotiation.fromCharacteristic(const []), isNull);
  });

  test('the CAIPO recording codec is 21', () {
    expect(kTargetCodecId, 21);
    expect(negotiation.isTarget(negotiation.fromByte(21)!), isTrue);
    expect(negotiation.isTarget(negotiation.fromByte(20)!), isFalse);
    expect(negotiation.isTarget(negotiation.fromByte(1)!), isFalse);
  });
}
