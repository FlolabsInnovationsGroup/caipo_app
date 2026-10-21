import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

import 'opus_container.dart';
import 'wav_pcm.dart';

const int kOpusSampleRate = 16000;
const int kOpusFrameSamples = 320;

/// Opus 16 kHz mono, 20 ms frames, packed as `[uint16 length][frame]...`.
class OpusCodec {
  OpusCodec();

  static final OpusCodec shared = OpusCodec();
  static Future<void>? _loading;

  SimpleOpusEncoder? _encoder;
  SimpleOpusDecoder? _decoder;

  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    initOpus(await opus_flutter.load());
  }

  /// Uses an already opened libopus. opus_flutter ships no Linux build, so
  /// tests on a Linux CI machine pass the system library here.
  // opus_dart types this through its own ffi proxy, so the library is passed
  // untyped, the same way opus_flutter.load() hands it over.
  static void useLibrary(dynamic library) {
    initOpus(library);
    _loading = Future<void>.value();
  }

  Uint8List encodeWav(Uint8List wav) => encodeSamples(toMono16k(parseWav(wav)));

  Uint8List encodeSamples(Int16List samples) {
    if (samples.isEmpty) {
      throw ArgumentError('PCM is empty.');
    }
    final encoder = _encoder ??= SimpleOpusEncoder(
      sampleRate: kOpusSampleRate,
      channels: 1,
      application: Application.voip,
    );
    final frames = <Uint8List>[];
    for (var offset = 0; offset < samples.length; offset += kOpusFrameSamples) {
      final frame = Int16List(kOpusFrameSamples);
      final remaining = samples.length - offset;
      final take = remaining < kOpusFrameSamples ? remaining : kOpusFrameSamples;
      frame.setRange(0, take, samples, offset);
      frames.add(encoder.encode(input: frame));
    }
    return const OpusFrameContainer().pack(frames);
  }

  Uint8List decodeContainer(Uint8List container) {
    final frames = const OpusFrameContainer().unpack(container);
    if (frames.isEmpty) {
      throw const FormatException('Opus container has no frames.');
    }
    final decoder = _decoder ??= SimpleOpusDecoder(sampleRate: kOpusSampleRate, channels: 1);
    final samples = BytesBuilder(copy: false);
    for (final frame in frames) {
      if (frame.isEmpty) throw const FormatException('Opus frame is empty.');
      final pcm = decoder.decode(input: frame);
      samples.add(pcmBytes(pcm));
    }
    final bytes = samples.toBytes();
    if (bytes.isEmpty) throw const FormatException('Opus decoded to no PCM.');
    return bytes;
  }
}
