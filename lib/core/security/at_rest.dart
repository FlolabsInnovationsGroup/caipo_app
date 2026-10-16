import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secret_store.dart';

/// AES-256-GCM for files on disk. The key lives in [SecretStore], not preferences.
class AtRestCipher {
  AtRestCipher({
    required this.secrets,
    required this.keyName,
    AesGcm? algorithm,
  }) : algorithm = algorithm ?? AesGcm.with256bits();

  static const historyKeyName = 'caipo.history.aes.key';
  static const mediaKeyName = 'caipo.media.aes.key';
  static const header = [0x43, 0x45, 0x4E, 0x43];

  final SecretStore secrets;
  final String keyName;
  final AesGcm algorithm;

  bool isSealed(Uint8List bytes) {
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  Future<Uint8List> seal(Uint8List plain) async {
    final box = await algorithm.encrypt(plain, secretKey: await _key());
    return Uint8List.fromList([...header, ...box.concatenation()]);
  }

  Future<Uint8List> open(Uint8List stored) async {
    if (!isSealed(stored)) return stored;
    final box = SecretBox.fromConcatenation(
      stored.sublist(header.length),
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await algorithm.decrypt(box, secretKey: await _key()));
  }

  Future<SecretKey> _key() async {
    final existing = await secrets.read(keyName);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(_decode(existing));
    }
    final created = await algorithm.newSecretKey();
    final bytes = Uint8List.fromList(await created.extractBytes());
    await secrets.write(keyName, _encode(bytes));
    return SecretKey(bytes);
  }

  List<int> _decode(String value) {
    final out = <int>[];
    for (var i = 0; i < value.length; i += 2) {
      out.add(int.parse(value.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  String _encode(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();
}
