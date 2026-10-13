import 'dart:typed_data';

import 'package:caipo_app/device/audio/packet_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final assembler = PacketAssembler();

  Uint8List frame(int packet, int fragment, List<int> payload) {
    return Uint8List.fromList([
      packet & 0xFF,
      (packet >> 8) & 0xFF,
      fragment,
      ...payload,
    ]);
  }

  test('ignores notifications shorter than the 3-byte header', () {
    final local = PacketAssembler();
    expect(local.add(Uint8List.fromList([1, 0])), isEmpty);
    expect(local.flush(), isEmpty);
  });

  test('strips the header and keeps a single fragment on flush', () {
    final local = PacketAssembler();
    expect(local.add(frame(7, 0, [9, 8, 7])), isEmpty);
    final packets = local.flush();
    expect(packets, hasLength(1));
    expect(packets.single.packetNumber, 7);
    expect(packets.single.payload, [9, 8, 7]);
    expect(packets.single.contiguous, isTrue);
  });

  test('reassembles fragments in index order when the next packet arrives', () {
    final local = PacketAssembler();
    local.add(frame(1, 1, [2]));
    local.add(frame(1, 0, [1]));
    final done = local.add(frame(2, 0, [3]));
    expect(done.single.packetNumber, 1);
    expect(done.single.payload, [1, 2]);
    expect(done.single.contiguous, isTrue);
  });

  test('marks a gap when a fragment index is missing', () {
    final local = PacketAssembler();
    local.add(frame(4, 0, [1]));
    local.add(frame(4, 2, [3]));
    final packets = local.flush();
    expect(packets.single.payload, [1, 3]);
    expect(packets.single.contiguous, isFalse);
  });

  test('packet numbers are little-endian and wrap at 65535', () {
    final local = PacketAssembler();
    final parsed = local.parseHeader(frame(65535, 0, [1]));
    expect(parsed!.packetNumber, 65535);
    local.add(frame(65535, 0, [1]));
    final wrapped = local.add(frame(0, 0, [2]));
    expect(wrapped.single.packetNumber, 65535);
    expect(assembler.parseHeader(frame(0x1234, 0, []) )!.packetNumber, 0x1234);
  });
}
