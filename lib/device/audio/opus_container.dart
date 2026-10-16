import 'dart:typed_data';

/// Opus frames inside an R03 transfer of content type 0x01.
///
/// The same layout is used in both directions:
/// `[uint16 length][frame][uint16 length][frame]...`
/// Lengths are little-endian. Each frame is one 20 ms Opus packet.
class OpusFrameContainer {
  const OpusFrameContainer();

  Uint8List pack(List<Uint8List> frames) {
    var size = 0;
    for (final frame in frames) {
      if (frame.length > 0xFFFF) {
        throw ArgumentError('Opus frame is ${frame.length} bytes.');
      }
      size += 2 + frame.length;
    }
    final bytes = Uint8List(size);
    var offset = 0;
    for (final frame in frames) {
      bytes[offset] = frame.length & 0xFF;
      bytes[offset + 1] = (frame.length >> 8) & 0xFF;
      bytes.setRange(offset + 2, offset + 2 + frame.length, frame);
      offset += 2 + frame.length;
    }
    return bytes;
  }

  List<Uint8List> unpack(Uint8List bytes) {
    final frames = <Uint8List>[];
    var offset = 0;
    while (offset < bytes.length) {
      if (offset + 2 > bytes.length) {
        throw FormatException('Truncated Opus frame length.');
      }
      final length = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
      if (offset + length > bytes.length) {
        throw FormatException('Truncated Opus frame.');
      }
      frames.add(Uint8List.sublistView(bytes, offset, offset + length));
      offset += length;
    }
    return frames;
  }
}
