import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/protocol/checksum.dart';
import 'package:caipo_app/device/protocol/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handshake, metadata, chunk and error are little-endian', () {
    final request = encodeHandshake(TransferMessageKind.transferRequest, 0x0201);
    expect(request, [0x01, 0x01, 0x02]);

    final payload = Uint8List.fromList([0xAA, 0xBB]);
    final crc = const TransferChecksum().crc32(payload);
    final metadata = encodeMetadata(
      MetadataMessage(
        transferId: 0x0201,
        totalSize: 0x04030201,
        contentType: kContentTypeAudio,
        crc32: crc,
        chunkCount: 1,
      ),
    );
    expect(metadata.sublist(0, 8), [0x03, 0x01, 0x02, 0x01, 0x02, 0x03, 0x04, 0x01]);
    expect(metadata.sublist(12), [0x01, 0x00]);

    final chunk = encodeChunk(
      ChunkMessage(transferId: 0x0201, sequence: 0, payload: payload),
    );
    expect(chunk, [0x04, 0x01, 0x02, 0x00, 0x00, 0x02, 0x00, 0xAA, 0xBB]);
    expect(chunk.length, kChunkHeaderBytes + payload.length);

    final error = encodeError(
      const ErrorMessage(
        transferId: 0x0201,
        code: kErrorChecksumMismatch,
        sequence: kErrorSeqNotApplicable,
      ),
    );
    expect(error, [0x06, 0x01, 0x02, 0x02, 0xFF, 0xFF]);

    expect(encodeHeartbeat(5), [0x10, 0x05]);
    expect(encodeHeartbeat(256), [0x10, 0x00]);
  });

  test('round-trips every confirmed message and rejects opcode 0', () {
    final payload = Uint8List.fromList([9, 8, 7]);
    final crc = const TransferChecksum().crc32(payload);
    final frames = [
      encodeHandshake(TransferMessageKind.transferReady, 4),
      encodeHandshake(TransferMessageKind.transferAck, 4),
      encodeMetadata(
        MetadataMessage(
          transferId: 4,
          totalSize: payload.length,
          contentType: kContentTypeImage,
          crc32: crc,
          chunkCount: 1,
        ),
      ),
      encodeChunk(ChunkMessage(transferId: 4, sequence: 3, payload: payload)),
      encodeError(
        const ErrorMessage(transferId: 4, code: kErrorBusy, sequence: kErrorSeqNotApplicable),
      ),
      encodeHeartbeat(255),
    ];
    for (final frame in frames) {
      expect(decodeWire(frame), isNotNull);
    }
    expect(decodeWire(Uint8List.fromList([0x00, 0x01])), isNull);
    expect(decodeWire(Uint8List(0)), isNull);
    expect((decodeWire(encodeHeartbeat(255)) as HeartbeatMessage).counter, 255);
  });

  test('a chunk longer than 502 bytes is rejected', () {
    expect(
      () => encodeChunk(
        ChunkMessage(transferId: 1, sequence: 0, payload: Uint8List(kMaxChunkBytes + 1)),
      ),
      throwsArgumentError,
    );
    final declared = Uint8List(kChunkHeaderBytes + 3);
    declared[0] = kOpcodeChunk;
    declared[5] = 4;
    expect(decodeWire(declared), isNull);
  });
}
