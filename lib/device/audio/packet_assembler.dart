import 'dart:typed_data';

import '../../core/config/constants.dart';

class AudioFragment {
  const AudioFragment({
    required this.packetNumber,
    required this.fragmentIndex,
    required this.payload,
  });

  /// 16-bit little-endian packet number. Wraps at 65535.
  final int packetNumber;
  final int fragmentIndex;
  final Uint8List payload;
}

class AssembledAudioPacket {
  const AssembledAudioPacket({
    required this.packetNumber,
    required this.payload,
    required this.contiguous,
  });

  final int packetNumber;
  final Uint8List payload;

  /// False when a fragment index was skipped. The bytes are still concatenated
  /// in index order. The spec does not define a gap-recovery rule.
  final bool contiguous;
}

/// Reassembles notifications that use the 3-byte header in spec section 4.3.
///
/// A packet is emitted when a different packet number arrives, or when
/// [flush] is called. The spec does not define an end-of-packet flag, so
/// holding the open packet until the next number (or an explicit flush) is
/// the conservative choice. See NOTES.md.
class PacketAssembler {
  final Map<int, Map<int, Uint8List>> _fragments = {};
  int? _openPacket;

  AudioFragment? parseHeader(Uint8List notification) {
    if (!kAudioHeaderRetained) {
      return AudioFragment(
        packetNumber: 0,
        fragmentIndex: 0,
        payload: Uint8List.fromList(notification),
      );
    }
    if (notification.length < kAudioHeaderSizeBytes) return null;
    final packetNumber = notification[0] | (notification[1] << 8);
    return AudioFragment(
      packetNumber: packetNumber,
      fragmentIndex: notification[2],
      payload: Uint8List.sublistView(notification, kAudioHeaderSizeBytes),
    );
  }

  List<AssembledAudioPacket> add(Uint8List notification) {
    final fragment = parseHeader(notification);
    if (fragment == null) return const [];

    final completed = <AssembledAudioPacket>[];
    if (_openPacket != null && _openPacket != fragment.packetNumber) {
      final emitted = _emit(_openPacket!);
      if (emitted != null) completed.add(emitted);
    }
    _openPacket = fragment.packetNumber;
    _fragments.putIfAbsent(fragment.packetNumber, () => {})[fragment.fragmentIndex] =
        fragment.payload;
    return completed;
  }

  List<AssembledAudioPacket> flush() {
    if (_openPacket == null) return const [];
    final emitted = _emit(_openPacket!);
    _openPacket = null;
    return emitted == null ? const [] : [emitted];
  }

  void reset() {
    _fragments.clear();
    _openPacket = null;
  }

  AssembledAudioPacket? _emit(int packetNumber) {
    final parts = _fragments.remove(packetNumber);
    _openPacket = null;
    if (parts == null || parts.isEmpty) return null;
    final indexes = parts.keys.toList()..sort();
    final builder = BytesBuilder(copy: false);
    for (final index in indexes) {
      builder.add(parts[index]!);
    }
    var contiguous = true;
    for (var i = 0; i < indexes.length; i++) {
      if (indexes[i] != i) {
        contiguous = false;
        break;
      }
    }
    return AssembledAudioPacket(
      packetNumber: packetNumber,
      payload: builder.toBytes(),
      contiguous: contiguous,
    );
  }
}
