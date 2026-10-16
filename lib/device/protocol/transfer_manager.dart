import 'dart:typed_data';

import '../../core/config/constants.dart';
import 'checksum.dart';
import 'chunker.dart';
import 'frame_queue.dart';
import 'messages.dart';
import 'proposed_commands.dart';

enum TransferPhase { idle, awaitingReady, sending, acknowledged, failed }

class TransferProgress {
  const TransferProgress({
    required this.phase,
    required this.chunksTotal,
    required this.chunksSent,
    this.detail,
    this.errorCode,
  });

  final TransferPhase phase;
  final int chunksTotal;
  final int chunksSent;
  final String? detail;
  final int? errorCode;
}

class PreparedTransfer {
  const PreparedTransfer({
    required this.transferId,
    required this.contentType,
    required this.crc32,
    required this.request,
    required this.metadata,
    required this.chunks,
  });

  final int transferId;
  final int contentType;
  final int crc32;
  final Uint8List request;
  final Uint8List metadata;
  final List<Uint8List> chunks;
}

/// Builds and exchanges an R03 transfer. Either side may send.
///
/// [exchange] writes real frames. It does not open a GATT connection. The
/// caller supplies the write function for [kOutboundCharacteristicUuid].
class TransferManager {
  const TransferManager({
    Chunker? chunker,
    TransferChecksum? checksum,
  }) : chunker = chunker ?? const Chunker(),
       checksum = checksum ?? const TransferChecksum();

  final Chunker chunker;
  final TransferChecksum checksum;

  PreparedTransfer prepare({
    required Uint8List payload,
    required int transferId,
    required int contentType,
    bool proposed = false,
  }) {
    final allowed = isKnownContentType(contentType) || (proposed && contentType == kProposedWifiContentType);
    if (!allowed) {
      throw ArgumentError('Unsupported content type $contentType.');
    }
    final pieces = chunker.split(payload);
    final digest = checksum.crc32(payload);
    return PreparedTransfer(
      transferId: transferId,
      contentType: contentType,
      crc32: digest,
      request: encodeHandshake(TransferMessageKind.transferRequest, transferId),
      metadata: encodeMetadata(
        MetadataMessage(
          transferId: transferId,
          totalSize: payload.length,
          contentType: contentType,
          crc32: digest,
          chunkCount: pieces.length,
        ),
      ),
      chunks: [
        for (final piece in pieces)
          encodeChunk(
            ChunkMessage(
              transferId: transferId,
              sequence: piece.sequence,
              payload: piece.payload,
            ),
          ),
      ],
    );
  }

  /// Waits [timeout] for TRANSFER_READY and for TRANSFER_ACK.
  ///
  /// No reply within [timeout] resends the last unacknowledged message, up to
  /// [maxRetries] times, then writes TRANSFER_ERROR 0x05 and fails.
  /// A TRANSFER_ERROR that names a sequence retransmits only that chunk,
  /// at most [maxRetries] times.
  Future<TransferProgress> exchange({
    required PreparedTransfer prepared,
    required void Function(Uint8List frame) write,
    required Stream<Uint8List> inbound,
    Duration timeout = kTransferAuthorisationTimeout,
    int maxRetries = kTransferMaxAttempts,
    TransferCancellation? cancellation,
  }) async {
    final queue = FrameQueue(inbound);
    try {
      final ready = await _awaitReady(
        prepared: prepared,
        write: write,
        queue: queue,
        timeout: timeout,
        maxRetries: maxRetries,
        cancellation: cancellation,
      );
      if (ready != null) return ready;
      if (cancellation?.cancelled == true) return _cancelled(prepared);

      write(prepared.metadata);
      var last = prepared.metadata;
      var outstanding = kErrorSeqNotApplicable;
      for (final chunk in prepared.chunks) {
        write(chunk);
        last = chunk;
        final decoded = decodeWire(chunk);
        if (decoded is ChunkMessage) outstanding = decoded.sequence;
      }

      final retries = <int, int>{};
      var silentTimeouts = 0;
      while (true) {
        if (cancellation?.cancelled == true) return _cancelled(prepared);
        final Uint8List? frame;
        try {
          frame = await queue.next(timeout, cancel: cancellation?.whenCancelled);
        } on TransferCancelled {
          return _cancelled(prepared);
        }
        if (frame == null) {
          silentTimeouts += 1;
          if (silentTimeouts > maxRetries) {
            _signalTimeout(write, prepared.transferId, outstanding);
            return _failed(prepared, 'Timed out waiting for TRANSFER_ACK.', kErrorTimeout);
          }
          write(last);
          continue;
        }
        silentTimeouts = 0;
        final message = decodeWire(frame);
        if (message is HandshakeMessage &&
            message.kind == TransferMessageKind.transferAck &&
            message.transferId == prepared.transferId) {
          return TransferProgress(
            phase: TransferPhase.acknowledged,
            chunksTotal: prepared.chunks.length,
            chunksSent: prepared.chunks.length,
          );
        }
        if (message is ErrorMessage && message.transferId == prepared.transferId) {
          if (!message.namesChunk || message.sequence >= prepared.chunks.length) {
            return _failed(
              prepared,
              'Transfer failed with error 0x${message.code.toRadixString(16)}.',
              message.code,
            );
          }
          final used = retries[message.sequence] ?? 0;
          if (used >= maxRetries) {
            return _failed(
              prepared,
              'Chunk ${message.sequence} failed after $maxRetries retries.',
              message.code,
            );
          }
          retries[message.sequence] = used + 1;
          last = prepared.chunks[message.sequence];
          outstanding = message.sequence;
          write(last);
        }
      }
    } finally {
      await queue.close();
    }
  }

  Future<TransferProgress?> _awaitReady({
    required PreparedTransfer prepared,
    required void Function(Uint8List frame) write,
    required FrameQueue queue,
    required Duration timeout,
    required int maxRetries,
    TransferCancellation? cancellation,
  }) async {
    var retries = 0;
    while (true) {
      if (cancellation?.cancelled == true) return _cancelled(prepared);
      write(prepared.request);
      final Uint8List? frame;
      try {
        frame = await queue.next(timeout, cancel: cancellation?.whenCancelled);
      } on TransferCancelled {
        return _cancelled(prepared);
      }
      if (frame == null) {
        retries += 1;
        if (retries > maxRetries) {
          _signalTimeout(write, prepared.transferId, kErrorSeqNotApplicable);
          return _failed(prepared, 'Timed out waiting for TRANSFER_READY.', kErrorTimeout);
        }
        continue;
      }
      final message = decodeWire(frame);
      if (message is ErrorMessage &&
          message.transferId == prepared.transferId &&
          message.code == kErrorBusy) {
        return _failed(prepared, 'The receiver is busy.', kErrorBusy);
      }
      if (message is HandshakeMessage &&
          message.kind == TransferMessageKind.transferReady &&
          message.transferId == prepared.transferId) {
        return null;
      }
    }
  }

  void _signalTimeout(void Function(Uint8List frame) write, int transferId, int sequence) {
    write(
      encodeError(
        ErrorMessage(
          transferId: transferId,
          code: kErrorTimeout,
          sequence: sequence,
        ),
      ),
    );
  }

  TransferProgress _cancelled(PreparedTransfer prepared) {
    return TransferProgress(
      phase: TransferPhase.failed,
      chunksTotal: prepared.chunks.length,
      chunksSent: 0,
      detail: 'Cancelled.',
    );
  }

  TransferProgress _failed(PreparedTransfer prepared, String detail, int code) {
    return TransferProgress(
      phase: TransferPhase.failed,
      chunksTotal: prepared.chunks.length,
      chunksSent: 0,
      detail: detail,
      errorCode: code,
    );
  }
}
