import 'dart:typed_data';

import 'checksum.dart';
import 'chunker.dart';
import 'messages.dart';
import 'retry_policy.dart';

enum TransferPhase { idle, awaitingReady, sending, acknowledged, failed }

class TransferProgress {
  const TransferProgress({
    required this.phase,
    required this.chunksTotal,
    required this.chunksSent,
    required this.mock,
    this.detail,
  });

  final TransferPhase phase;
  final int chunksTotal;
  final int chunksSent;

  /// True when no bytes were written because the wire format is undefined.
  final bool mock;
  final String? detail;
}

/// Contract for spec section 6. The flow is represented, and chunking plus
/// checksums run for real, but nothing is written to a characteristic.
class TransferManager {
  TransferManager({
    Chunker? chunker,
    TransferChecksum? checksum,
    TransferRetryPolicy? retryPolicy,
  }) : chunker = chunker ?? const Chunker(),
       checksum = checksum ?? const TransferChecksum(),
       retryPolicy = retryPolicy ?? const TransferRetryPolicy();

  final Chunker chunker;
  final TransferChecksum checksum;
  final TransferRetryPolicy retryPolicy;

  Future<TransferProgress> send(Uint8List payload) async {
    final chunks = chunker.split(payload);
    final digest = checksum.compute(payload);
    // Touch the digest so a mock send still exercises the integrity step.
    if (digest.isEmpty && payload.isNotEmpty) {
      return const TransferProgress(
        phase: TransferPhase.failed,
        chunksTotal: 0,
        chunksSent: 0,
        mock: true,
        detail: 'Checksum produced no bytes.',
      );
    }
    return TransferProgress(
      phase: TransferPhase.failed,
      chunksTotal: chunks.length,
      chunksSent: 0,
      mock: true,
      detail:
          'R03 wire format is undefined. No TRANSFER_REQUEST was written. '
          '${chunks.length} logical chunks and a ${digest.length}-byte '
          'checksum were prepared in memory only.',
    );
  }

  /// The app must not transmit before TRANSFER_READY. This mock never
  /// receives one, so it never advances to sending.
  bool mayTransmit(TransferMessage? ready) =>
      ready?.kind == TransferMessageKind.transferReady &&
      ready!.kind.placeholderOpcode != kUnresolvedOpcodeSentinel;

  static const int kUnresolvedOpcodeSentinel = 0x00;
}
