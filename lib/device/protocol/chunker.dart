import 'dart:typed_data';

import '../../core/config/constants.dart';

class TransferTooLarge implements Exception {
  const TransferTooLarge(this.size);

  final int size;

  @override
  String toString() =>
      'Transfer is $size bytes. The specified maximum is $kMaxTransferBytes.';
}

class TransferChunk {
  const TransferChunk({required this.sequence, required this.payload});

  /// Zero-based, matching the sequence numbers in spec section 6.1.
  final int sequence;

  /// At most [kMaxChunkBytes]. The on-wire encoding of [sequence] is TBD.
  final Uint8List payload;
}

class Chunker {
  const Chunker({this.maxChunkBytes = kMaxChunkBytes});

  final int maxChunkBytes;

  List<TransferChunk> split(Uint8List data) {
    if (data.length > kMaxTransferBytes) {
      throw TransferTooLarge(data.length);
    }
    if (data.isEmpty || maxChunkBytes <= 0) return const [];
    final chunks = <TransferChunk>[];
    var offset = 0;
    var sequence = 0;
    while (offset < data.length) {
      final end = offset + maxChunkBytes > data.length
          ? data.length
          : offset + maxChunkBytes;
      chunks.add(
        TransferChunk(
          sequence: sequence,
          payload: Uint8List.sublistView(data, offset, end),
        ),
      );
      sequence += 1;
      offset = end;
    }
    return chunks;
  }
}
