import 'dart:math';
import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:caipo_app/device/audio/opus_container.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/load_opus.dart';

void main() {
  setUpAll(loadOpusForTests);

  test('16 kHz mono 20 ms frames round-trip through the length prefix', () {
    final samples = Int16List(kOpusFrameSamples * 4);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (sin(2 * pi * 440 * i / kOpusSampleRate) * 8000).round();
    }
    final container = OpusCodec.shared.encodeSamples(samples);
    final frames = const OpusFrameContainer().unpack(container);
    expect(frames, hasLength(4));
    for (final frame in frames) {
      expect(frame, isNotEmpty);
      expect(frame.length, lessThan(kOpusFrameSamples * 2));
    }
    final decoded = OpusCodec.shared.decodeContainer(container);
    expect(decoded.length, samples.length * 2);
    final view = ByteData.sublistView(decoded);
    var best = -1.0;
    for (var lag = 0; lag < kOpusFrameSamples; lag++) {
      var dot = 0.0;
      var energyIn = 0.0;
      var energyOut = 0.0;
      final count = samples.length - lag;
      for (var i = 0; i < count; i++) {
        final output = view.getInt16((i + lag) * 2, Endian.little).toDouble();
        final input = samples[i].toDouble();
        dot += input * output;
        energyIn += input * input;
        energyOut += output * output;
      }
      final correlation = dot / sqrt(energyIn * energyOut);
      if (correlation > best) best = correlation;
    }
    expect(best, greaterThan(0.9));
  });

  test('chunk payload is min(502, write length minus the 7 byte header)', () {
    expect(chunkPayloadBytes(509), 502);
    expect(chunkPayloadBytes(20), 13);
    expect(chunkPayloadBytes(7), 1);
  });
}
