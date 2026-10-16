import 'dart:async';
import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/audio/audio_transmitter.dart';
import 'package:caipo_app/device/protocol/chunker.dart';
import 'package:caipo_app/device/protocol/incoming_transfer.dart';
import 'package:caipo_app/device/protocol/messages.dart';
import 'package:caipo_app/device/protocol/transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manager = TransferManager();

  PreparedTransfer sample() {
    return manager.prepare(
      payload: Uint8List.fromList([1, 2, 3, 4]),
      transferId: 7,
      contentType: kContentTypeAudio,
    );
  }

  test('the last chunk sequence is total chunks minus one', () {
    final payload = Uint8List(kMaxChunkBytes + 3);
    final prepared = manager.prepare(
      payload: payload,
      transferId: 1,
      contentType: kContentTypeOther,
    );
    expect(prepared.chunks, hasLength(2));
    final last = decodeWire(prepared.chunks.last) as ChunkMessage;
    final metadata = decodeWire(prepared.metadata) as MetadataMessage;
    expect(last.sequence, metadata.chunkCount - 1);
    expect(metadata.crc32, prepared.crc32);
    expect(metadata.totalSize, payload.length);
  });

  test('a receiver reassembles the prepared transfer', () {
    final payload = Uint8List.fromList([9, 8, 7, 6]);
    final prepared = manager.prepare(
      payload: payload,
      transferId: 3,
      contentType: kContentTypeAudio,
    );
    final incoming = IncomingTransfer();
    final ready = incoming.handle(prepared.request)!;
    expect(
      (decodeWire(ready.frame!) as HandshakeMessage).kind,
      TransferMessageKind.transferReady,
    );
    expect(incoming.handle(prepared.metadata)!.frame, isNull);
    TransferReply? done;
    for (final chunk in prepared.chunks) {
      done = incoming.handle(chunk);
    }
    expect(done!.payload, payload);
    expect(done.contentType, kContentTypeAudio);
    expect(
      (decodeWire(done.frame!) as HandshakeMessage).kind,
      TransferMessageKind.transferAck,
    );
  });

  test('checksum mismatch and an unsupported type are rejected', () {
    final incoming = IncomingTransfer();
    incoming.handle(encodeHandshake(TransferMessageKind.transferRequest, 1));
    final mismatch = incoming.handle(
      encodeMetadata(
        const MetadataMessage(
          transferId: 1,
          totalSize: 1,
          contentType: kContentTypeAudio,
          crc32: 0,
          chunkCount: 1,
        ),
      ),
    );
    expect(mismatch!.frame, isNull);
    final failed = incoming.handle(
      encodeChunk(
        ChunkMessage(transferId: 1, sequence: 0, payload: Uint8List.fromList([1])),
      ),
    );
    expect(failed!.errorCode, kErrorChecksumMismatch);

    final again = IncomingTransfer();
    again.handle(encodeHandshake(TransferMessageKind.transferRequest, 2));
    final unsupported = again.handle(
      encodeMetadata(
        const MetadataMessage(
          transferId: 2,
          totalSize: 0,
          contentType: 0x09,
          crc32: 0,
          chunkCount: 0,
        ),
      ),
    );
    expect(unsupported!.errorCode, kErrorUnsupportedType);
  });

  test('a second request while one is open is busy', () {
    final incoming = IncomingTransfer();
    incoming.handle(encodeHandshake(TransferMessageKind.transferRequest, 1));
    final busy = incoming.handle(encodeHandshake(TransferMessageKind.transferRequest, 2))!;
    final error = decodeWire(busy.frame!) as ErrorMessage;
    expect(error.code, kErrorBusy);
    expect(error.transferId, 2);
  });

  test('a too-large metadata size is rejected', () {
    final incoming = IncomingTransfer();
    incoming.handle(encodeHandshake(TransferMessageKind.transferRequest, 1));
    final reply = incoming.handle(
      encodeMetadata(
        MetadataMessage(
          transferId: 1,
          totalSize: kSequenceAddressableBytes + 1,
          contentType: kContentTypeOther,
          crc32: 0,
          chunkCount: 0,
        ),
      ),
    );
    expect(reply!.errorCode, kErrorTooLarge);
  });

  test('exchange retransmits only the named chunk', () async {
    final prepared = sample();
    final inbound = StreamController<Uint8List>();
    final written = <Uint8List>[];
    final pending = manager.exchange(
      prepared: prepared,
      write: written.add,
      inbound: inbound.stream,
      timeout: const Duration(milliseconds: 200),
    );
    await Future<void>.delayed(Duration.zero);
    inbound.add(encodeHandshake(TransferMessageKind.transferReady, 7));
    await Future<void>.delayed(Duration.zero);
    final beforeRetry = written.length;
    inbound.add(
      encodeError(
        const ErrorMessage(transferId: 7, code: kErrorSequenceGap, sequence: 0),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(written.length, beforeRetry + 1);
    expect(written.last, prepared.chunks.single);
    inbound.add(encodeHandshake(TransferMessageKind.transferAck, 7));
    final progress = await pending;
    expect(progress.phase, TransferPhase.acknowledged);
    await inbound.close();
  });

  test('silence resends the last message, then sends timeout', () async {
    final prepared = sample();
    final inbound = StreamController<Uint8List>();
    final written = <Uint8List>[];
    final progress = await manager.exchange(
      prepared: prepared,
      write: written.add,
      inbound: inbound.stream,
      timeout: const Duration(milliseconds: 20),
    );
    expect(progress.phase, TransferPhase.failed);
    expect(progress.errorCode, kErrorTimeout);
    expect(_count(written, prepared.request), 4);
    final error = decodeWire(written.last) as ErrorMessage;
    expect(error.code, kErrorTimeout);
    expect(error.sequence, kErrorSeqNotApplicable);
    await inbound.close();
  });

  test('silence after the chunks resends the last chunk', () async {
    final prepared = sample();
    final inbound = StreamController<Uint8List>();
    final written = <Uint8List>[];
    final pending = manager.exchange(
      prepared: prepared,
      write: written.add,
      inbound: inbound.stream,
      timeout: const Duration(milliseconds: 20),
    );
    await Future<void>.delayed(Duration.zero);
    inbound.add(encodeHandshake(TransferMessageKind.transferReady, 7));
    final progress = await pending;
    expect(progress.phase, TransferPhase.failed);
    expect(progress.errorCode, kErrorTimeout);
    expect(_count(written, prepared.chunks.single), 4);
    final error = decodeWire(written.last) as ErrorMessage;
    expect(error.code, kErrorTimeout);
    expect(error.sequence, 0);
    await inbound.close();
  });

  test('chunks smaller than 502 bytes still reassemble', () {
    final payload = Uint8List.fromList([1, 2, 3, 4]);
    final prepared = TransferManager(chunker: const Chunker(maxChunkBytes: 2)).prepare(
      payload: payload,
      transferId: 4,
      contentType: kContentTypeOther,
    );
    expect(prepared.chunks, hasLength(2));
    final incoming = IncomingTransfer();
    incoming.handle(prepared.request);
    expect(incoming.handle(prepared.metadata)!.frame, isNull);
    TransferReply? done;
    for (final chunk in prepared.chunks) {
      done = incoming.handle(chunk);
    }
    expect(done!.payload, payload);
  });

  test('AI reply audio is one audio transfer of length-prefixed frames', () {
    final frame = Uint8List.fromList([1, 2, 3]);
    final prepared = const AudioTransmitter().prepareReply([frame], transferId: 11);
    final metadata = decodeWire(prepared.metadata) as MetadataMessage;
    expect(metadata.contentType, kContentTypeAudio);
    expect(metadata.totalSize, 5);
    final chunk = decodeWire(prepared.chunks.single) as ChunkMessage;
    expect(chunk.payload, [3, 0, 1, 2, 3]);
  });
}

int _count(List<Uint8List> frames, Uint8List target) {
  var count = 0;
  for (final frame in frames) {
    if (frame.length != target.length) continue;
    var same = true;
    for (var i = 0; i < frame.length; i++) {
      if (frame[i] != target[i]) {
        same = false;
        break;
      }
    }
    if (same) count += 1;
  }
  return count;
}
