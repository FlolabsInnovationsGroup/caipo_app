import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/config/constants.dart';

/// R03 integrity check. The spec allows CRC-32 or SHA-256 and does not choose.
/// Both are implemented. [kTransferChecksumAlgorithm] selects the placeholder.
class TransferChecksum {
  const TransferChecksum();

  Uint8List compute(Uint8List data, {String? algorithm}) {
    final selected = algorithm ?? kTransferChecksumAlgorithm;
    switch (selected) {
      case 'crc32':
        return _crc32Bytes(data);
      case 'sha256':
        return Uint8List.fromList(sha256.convert(data).bytes);
      default:
        throw ArgumentError('Unknown checksum algorithm "$selected".');
    }
  }

  bool matches(Uint8List data, Uint8List expected, {String? algorithm}) {
    final actual = compute(data, algorithm: algorithm);
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  /// ISO-HDLC CRC-32, reflected polynomial 0xEDB88320.
  int crc32(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 1) != 0) {
          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {
          crc = crc >>> 1;
        }
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  Uint8List _crc32Bytes(Uint8List data) {
    final value = crc32(data);
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }
}
