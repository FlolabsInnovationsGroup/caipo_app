import 'dart:typed_data';

/// 16-bit little-endian PCM, as stored in a WAV data chunk.
class PcmWav {
  const PcmWav({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;

  /// Interleaved when [channels] is greater than one.
  final Int16List samples;
}

PcmWav parseWav(Uint8List bytes) {
  if (bytes.length < 12 || String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
    throw const FormatException('Not a WAV file.');
  }
  var offset = 12;
  int? rate;
  int? channels;
  int? bits;
  Uint8List? data;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
    final start = offset + 8;
    final end = start + size;
    if (end > bytes.length) {
      throw FormatException('Truncated WAV chunk $id.');
    }
    if (id == 'fmt ') {
      final fmt = ByteData.sublistView(bytes, start, end);
      if (fmt.lengthInBytes < 16) throw const FormatException('WAV fmt chunk is short.');
      final format = fmt.getUint16(0, Endian.little);
      if (format != 1) throw FormatException('WAV format $format is not PCM.');
      channels = fmt.getUint16(2, Endian.little);
      rate = fmt.getUint32(4, Endian.little);
      bits = fmt.getUint16(14, Endian.little);
    } else if (id == 'data') {
      data = Uint8List.sublistView(bytes, start, end);
    }
    offset = end + (size.isOdd ? 1 : 0);
  }
  if (rate == null || channels == null || bits == null || data == null) {
    throw const FormatException('WAV is missing fmt or data.');
  }
  if (channels < 1) throw const FormatException('WAV has no channels.');
  if (bits != 16) throw FormatException('WAV is $bits-bit. 16-bit PCM is required.');
  final samples = Int16List(data.length ~/ 2);
  final view = ByteData.sublistView(data);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = view.getInt16(i * 2, Endian.little);
  }
  return PcmWav(sampleRate: rate, channels: channels, samples: samples);
}

/// Downmixes to mono and linearly resamples to 16 kHz.
Int16List toMono16k(PcmWav wav) {
  final frames = wav.samples.length ~/ wav.channels;
  final mono = Int16List(frames);
  for (var i = 0; i < frames; i++) {
    var sum = 0;
    for (var channel = 0; channel < wav.channels; channel++) {
      sum += wav.samples[i * wav.channels + channel];
    }
    mono[i] = (sum / wav.channels).round();
  }
  if (wav.sampleRate == 16000) return mono;
  if (wav.sampleRate <= 0 || mono.isEmpty) {
    throw FormatException('WAV sample rate ${wav.sampleRate} cannot be resampled.');
  }
  final outLength = (mono.length * 16000 / wav.sampleRate).floor();
  final out = Int16List(outLength);
  for (var i = 0; i < outLength; i++) {
    final source = i * wav.sampleRate / 16000;
    final left = source.floor();
    final right = left + 1 < mono.length ? left + 1 : mono.length - 1;
    final fraction = source - left;
    out[i] = (mono[left] * (1 - fraction) + mono[right] * fraction).round();
  }
  return out;
}

Uint8List pcmBytes(Int16List samples) {
  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

/// 16 kHz mono 16-bit WAV.
Uint8List writePcmWav(Uint8List pcm, {int sampleRate = 16000}) {
  final header = ByteData(44);
  header.setUint8(0, 0x52);
  header.setUint8(1, 0x49);
  header.setUint8(2, 0x46);
  header.setUint8(3, 0x46);
  header.setUint32(4, 36 + pcm.length, Endian.little);
  header.setUint8(8, 0x57);
  header.setUint8(9, 0x41);
  header.setUint8(10, 0x56);
  header.setUint8(11, 0x45);
  header.setUint8(12, 0x66);
  header.setUint8(13, 0x6d);
  header.setUint8(14, 0x74);
  header.setUint8(15, 0x20);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.setUint8(36, 0x64);
  header.setUint8(37, 0x61);
  header.setUint8(38, 0x74);
  header.setUint8(39, 0x61);
  header.setUint32(40, pcm.length, Endian.little);
  final wav = Uint8List(44 + pcm.length);
  wav.setRange(0, 44, header.buffer.asUint8List(header.offsetInBytes, header.lengthInBytes));
  wav.setRange(44, wav.length, pcm);
  return wav;
}
