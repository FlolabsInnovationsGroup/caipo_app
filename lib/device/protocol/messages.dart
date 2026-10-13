import '../../core/config/constants.dart';

/// R03 message names. Opcode byte values are TBD and currently identical
/// placeholders, so they cannot identify a message on the wire.
enum TransferMessageKind {
  transferRequest(kOpcodeTransferRequest),
  transferReady(kOpcodeTransferReady),
  metadata(kOpcodeMetadata),
  chunk(kOpcodeChunk),
  transferAck(kOpcodeTransferAck),
  transferError(kOpcodeTransferError);

  const TransferMessageKind(this.placeholderOpcode);

  final int placeholderOpcode;
}

class TransferMessage {
  const TransferMessage({
    required this.kind,
    this.sequence,
    this.description,
  });

  final TransferMessageKind kind;
  final int? sequence;
  final String? description;

  /// The binary layout is undefined. This never produces device bytes.
  List<int> toWireBytes() => const [];
}
