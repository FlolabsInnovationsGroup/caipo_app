import 'dart:typed_data';

import '../../core/config/constants.dart';

/// R03 message names. Byte 0 of every message is the opcode.
enum TransferMessageKind {
  transferRequest(kOpcodeTransferRequest),
  transferReady(kOpcodeTransferReady),
  metadata(kOpcodeMetadata),
  chunk(kOpcodeChunk),
  transferAck(kOpcodeTransferAck),
  transferError(kOpcodeTransferError),
  heartbeat(kOpcodeHeartbeat);

  const TransferMessageKind(this.opcode);

  final int opcode;
}

/// TRANSFER_REQUEST, TRANSFER_READY and TRANSFER_ACK.
///
/// The IoT note names these opcodes and the transfer id used by every other
/// transfer message, and it does not list further fields. They are encoded
/// as opcode + uint16 transfer id so either side can correlate them.
class HandshakeMessage {
  const HandshakeMessage({required this.kind, required this.transferId});

  final TransferMessageKind kind;
  final int transferId;
}

class MetadataMessage {
  const MetadataMessage({
    required this.transferId,
    required this.totalSize,
    required this.contentType,
    required this.crc32,
    required this.chunkCount,
  });

  final int transferId;
  final int totalSize;
  final int contentType;
  final int crc32;
  final int chunkCount;
}

class ChunkMessage {
  const ChunkMessage({
    required this.transferId,
    required this.sequence,
    required this.payload,
  });

  final int transferId;
  final int sequence;
  final Uint8List payload;
}

class ErrorMessage {
  const ErrorMessage({
    required this.transferId,
    required this.code,
    required this.sequence,
  });

  final int transferId;
  final int code;
  final int sequence;

  bool get namesChunk => sequence != kErrorSeqNotApplicable;
}

class HeartbeatMessage {
  const HeartbeatMessage(this.counter);

  /// uint8. The device adds one each beat and wraps 255 to 0.
  final int counter;
}

Uint8List encodeHandshake(TransferMessageKind kind, int transferId) {
  if (kind != TransferMessageKind.transferRequest &&
      kind != TransferMessageKind.transferReady &&
      kind != TransferMessageKind.transferAck) {
    throw ArgumentError('${kind.name} is not a handshake message.');
  }
  return Uint8List.fromList([
    kind.opcode,
    transferId & 0xFF,
    (transferId >> 8) & 0xFF,
  ]);
}

Uint8List encodeMetadata(MetadataMessage message) {
  final crc = message.crc32 & 0xFFFFFFFF;
  return Uint8List.fromList([
    kOpcodeMetadata,
    message.transferId & 0xFF,
    (message.transferId >> 8) & 0xFF,
    message.totalSize & 0xFF,
    (message.totalSize >> 8) & 0xFF,
    (message.totalSize >> 16) & 0xFF,
    (message.totalSize >> 24) & 0xFF,
    message.contentType & 0xFF,
    crc & 0xFF,
    (crc >> 8) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 24) & 0xFF,
    message.chunkCount & 0xFF,
    (message.chunkCount >> 8) & 0xFF,
  ]);
}

Uint8List encodeChunk(ChunkMessage message) {
  if (message.payload.length > kMaxChunkBytes) {
    throw ArgumentError(
      'Chunk payload is ${message.payload.length} bytes. The maximum is $kMaxChunkBytes.',
    );
  }
  final bytes = Uint8List(kChunkHeaderBytes + message.payload.length);
  bytes[0] = kOpcodeChunk;
  bytes[1] = message.transferId & 0xFF;
  bytes[2] = (message.transferId >> 8) & 0xFF;
  bytes[3] = message.sequence & 0xFF;
  bytes[4] = (message.sequence >> 8) & 0xFF;
  bytes[5] = message.payload.length & 0xFF;
  bytes[6] = (message.payload.length >> 8) & 0xFF;
  bytes.setRange(kChunkHeaderBytes, bytes.length, message.payload);
  return bytes;
}

Uint8List encodeError(ErrorMessage message) {
  return Uint8List.fromList([
    kOpcodeTransferError,
    message.transferId & 0xFF,
    (message.transferId >> 8) & 0xFF,
    message.code & 0xFF,
    message.sequence & 0xFF,
    (message.sequence >> 8) & 0xFF,
  ]);
}

Uint8List encodeHeartbeat(int counter) {
  return Uint8List.fromList([kOpcodeHeartbeat, counter & 0xFF]);
}

/// Returns null when the bytes are not a complete, recognised message.
/// Opcode 0x00 is reserved and never decodes.
Object? decodeWire(Uint8List bytes) {
  if (bytes.isEmpty || bytes[0] == 0x00) return null;
  switch (bytes[0]) {
    case kOpcodeTransferRequest:
      return _handshake(bytes, TransferMessageKind.transferRequest);
    case kOpcodeTransferReady:
      return _handshake(bytes, TransferMessageKind.transferReady);
    case kOpcodeTransferAck:
      return _handshake(bytes, TransferMessageKind.transferAck);
    case kOpcodeMetadata:
      return _metadata(bytes);
    case kOpcodeChunk:
      return _chunk(bytes);
    case kOpcodeTransferError:
      return _error(bytes);
    case kOpcodeHeartbeat:
      if (bytes.length != 2) return null;
      return HeartbeatMessage(bytes[1]);
    default:
      return null;
  }
}

HandshakeMessage? _handshake(Uint8List bytes, TransferMessageKind kind) {
  if (bytes.length != 3) return null;
  return HandshakeMessage(kind: kind, transferId: _u16(bytes, 1));
}

MetadataMessage? _metadata(Uint8List bytes) {
  if (bytes.length != 14) return null;
  return MetadataMessage(
    transferId: _u16(bytes, 1),
    totalSize: _u32(bytes, 3),
    contentType: bytes[7],
    crc32: _u32(bytes, 8),
    chunkCount: _u16(bytes, 12),
  );
}

ChunkMessage? _chunk(Uint8List bytes) {
  if (bytes.length < kChunkHeaderBytes) return null;
  final length = _u16(bytes, 5);
  if (length > kMaxChunkBytes || bytes.length != kChunkHeaderBytes + length) {
    return null;
  }
  return ChunkMessage(
    transferId: _u16(bytes, 1),
    sequence: _u16(bytes, 3),
    payload: Uint8List.sublistView(bytes, kChunkHeaderBytes),
  );
}

ErrorMessage? _error(Uint8List bytes) {
  if (bytes.length != 6) return null;
  return ErrorMessage(
    transferId: _u16(bytes, 1),
    code: bytes[3],
    sequence: _u16(bytes, 4),
  );
}

int _u16(Uint8List bytes, int offset) => bytes[offset] | (bytes[offset + 1] << 8);

int _u32(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

bool isKnownContentType(int contentType) =>
    contentType == kContentTypeAudio ||
    contentType == kContentTypeImage ||
    contentType == kContentTypeOther;
