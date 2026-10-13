import 'dart:convert';
import 'dart:typed_data';

import 'package:caipo_app/device/protocol/checksum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const checksum = TransferChecksum();

  test('CRC-32 of 123456789 is the ISO-HDLC check value', () {
    final bytes = Uint8List.fromList(ascii.encode('123456789'));
    expect(checksum.crc32(bytes), 0xCBF43926);
  });

  test('SHA-256 of abc matches the known digest', () {
    final digest = checksum.compute(Uint8List.fromList(ascii.encode('abc')), algorithm: 'sha256');
    expect(
      digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('the selected algorithm round-trips', () {
    final data = Uint8List.fromList([1, 2, 3, 4]);
    final digest = checksum.compute(data);
    expect(checksum.matches(data, digest), isTrue);
    expect(checksum.matches(Uint8List.fromList([1, 2, 3, 5]), digest), isFalse);
  });
}
