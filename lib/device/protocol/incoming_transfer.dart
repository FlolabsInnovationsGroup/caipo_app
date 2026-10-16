import 'dart:typed_data';

import '../../core/config/constants.dart';
import 'checksum.dart';
import 'messages.dart';

class TransferReply {
  const TransferReply({this.frame, this.payload, this.contentType, this.errorCode});

  final Uint8List? frame;
  final Uint8List? payload;
  final int? contentType;
  final int? errorCode;

  bool get completed => payload != null;
}

/// Receives one R03 transfer at a time and answers on the same byte stream.
class IncomingTransfer {
  IncomingTransfer({this.checksum = const TransferChecksum()});

  final TransferChecksum checksum;

  bool _active = false;
  int? _id;
  int? _size;
  int? _count;
  int? _crc;
  int? _type;
  int _next = 0;
  int _timeouts = 0;
  final Map<int, Uint8List> _chunks = {};

  bool get active => _active;

  Uint8List? _abandoned;

  /// Bytes held when the transfer is dropped. R03 has no resume, so this is
  /// only a local partial, not a point to continue from.
  Uint8List? takeAbandoned() {
    final bytes = _abandoned;
    _abandoned = null;
    return bytes;
  }

  TransferReply? handle(Uint8List frame) {
    final message = decodeWire(frame);
    if (message is HeartbeatMessage) return null;
    if (message is HandshakeMessage && message.kind == TransferMessageKind.transferRequest) {
      return _request(message);
    }
    if (!_active || _id == null) return null;
    if (message is MetadataMessage) return _metadata(message);
    if (message is ChunkMessage) return _chunk(message);
    return null;
  }

  /// Called when [kTransferAuthorisationTimeout] passes with no next frame.
  /// Sends TIMEOUT up to [kTransferMaxAttempts] times, then drops the transfer.
  Uint8List? onTimeout() {
    if (!_active || _id == null) return null;
    _timeouts += 1;
    final sequence = _size == null ? kErrorSeqNotApplicable : _next;
    final frame = encodeError(
      ErrorMessage(
        transferId: _id!,
        code: kErrorTimeout,
        sequence: sequence,
      ),
    );
    if (_timeouts >= kTransferMaxAttempts) {
      _abandoned = _partialBytes();
      _reset();
    }
    return frame;
  }

  TransferReply _request(HandshakeMessage message) {
    if (_active) {
      return TransferReply(
        frame: encodeError(
          ErrorMessage(
            transferId: message.transferId,
            code: kErrorBusy,
            sequence: kErrorSeqNotApplicable,
          ),
        ),
        errorCode: kErrorBusy,
      );
    }
    _reset();
    _active = true;
    _id = message.transferId;
    return TransferReply(
      frame: encodeHandshake(TransferMessageKind.transferReady, message.transferId),
    );
  }

  TransferReply _metadata(MetadataMessage message) {
    if (message.transferId != _id) return const TransferReply();
    if (message.totalSize > kMaxTransferBytes || message.totalSize > kSequenceAddressableBytes) {
      return _fail(kErrorTooLarge, kErrorSeqNotApplicable);
    }
    if (!isKnownContentType(message.contentType)) {
      return _fail(kErrorUnsupportedType, kErrorSeqNotApplicable);
    }
    final minimum = message.totalSize == 0
        ? 0
        : (message.totalSize + kMaxChunkBytes - 1) ~/ kMaxChunkBytes;
    final maximum = message.totalSize;
    if (message.chunkCount < minimum || message.chunkCount > maximum) {
      return _fail(kErrorUnknown, kErrorSeqNotApplicable);
    }
    _size = message.totalSize;
    _count = message.chunkCount;
    _crc = message.crc32;
    _type = message.contentType;
    _next = 0;
    _chunks.clear();
    if (message.chunkCount == 0) return _finish();
    return const TransferReply();
  }

  TransferReply _chunk(ChunkMessage message) {
    if (message.transferId != _id || _count == null || _size == null) {
      return const TransferReply();
    }
    if (message.payload.length > kMaxChunkBytes) {
      return _fail(kErrorUnknown, message.sequence);
    }
    if (message.sequence >= _count!) {
      return _fail(kErrorSequenceGap, message.sequence);
    }
    final stored = _chunks[message.sequence];
    if (stored != null) {
      if (_same(stored, message.payload)) return const TransferReply();
      return _fail(kErrorSequenceGap, message.sequence);
    }
    if (message.sequence != _next) {
      return _fail(kErrorSequenceGap, message.sequence);
    }
    _chunks[message.sequence] = Uint8List.fromList(message.payload);
    _next += 1;
    _timeouts = 0;
    if (_next == _count) return _finish();
    return const TransferReply();
  }

  TransferReply _finish() {
    final payload = BytesBuilder(copy: false);
    for (var sequence = 0; sequence < (_count ?? 0); sequence++) {
      final part = _chunks[sequence];
      if (part == null) return _fail(kErrorSequenceGap, sequence);
      payload.add(part);
    }
    final bytes = payload.toBytes();
    if (bytes.length != _size) {
      return _fail(kErrorUnknown, kErrorSeqNotApplicable);
    }
    if (checksum.crc32(bytes) != _crc) {
      return _fail(kErrorChecksumMismatch, kErrorSeqNotApplicable);
    }
    final type = _type;
    final id = _id!;
    _reset();
    return TransferReply(
      frame: encodeHandshake(TransferMessageKind.transferAck, id),
      payload: bytes,
      contentType: type,
    );
  }

  TransferReply _fail(int code, int sequence) {
    final id = _id ?? 0;
    _reset();
    return TransferReply(
      frame: encodeError(
        ErrorMessage(transferId: id, code: code, sequence: sequence),
      ),
      errorCode: code,
    );
  }

  Uint8List? _partialBytes() {
    if (_chunks.isEmpty) return null;
    final ordered = _chunks.keys.toList()..sort();
    final builder = BytesBuilder(copy: false);
    for (final sequence in ordered) {
      builder.add(_chunks[sequence]!);
    }
    final bytes = builder.toBytes();
    return bytes.isEmpty ? null : bytes;
  }

  void _reset() {
    _active = false;
    _id = null;
    _size = null;
    _count = null;
    _crc = null;
    _type = null;
    _next = 0;
    _timeouts = 0;
    _chunks.clear();
  }

  bool _same(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
