import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/security/at_rest.dart';
import '../../core/security/secret_store.dart';

/// Local conversation history. The file is AES-GCM ciphertext.
///
/// The 256-bit key is in the Keychain / Android Keystore. A key left in
/// preferences from an earlier build is moved once, then removed.
class ConversationHistoryStore {
  ConversationHistoryStore({
    required this.directory,
    required this.secrets,
    this.legacyPreferences,
    AesGcm? algorithm,
  }) : algorithm = algorithm ?? AesGcm.with256bits();

  static const legacyKeyPreference = 'history.aes.key';

  final Directory directory;
  final SecretStore secrets;
  final SharedPreferences? legacyPreferences;
  final AesGcm algorithm;

  File get _file => File('${directory.path}${Platform.pathSeparator}history.bin');

  Future<void> append({
    required String role,
    required String text,
    String status = 'sent',
    String? recording,
  }) async {
    final entries = await load();
    entries.add({
      'role': role,
      'text': text,
      'status': status,
      'at': DateTime.now().toUtc().toIso8601String(),
      'recording': ?recording,
    });
    await replace(entries);
  }

  Future<String> saveRecording(Uint8List bytes) async {
    final name = 'unsent_${DateTime.now().microsecondsSinceEpoch}.bin';
    final box = await algorithm.encrypt(bytes, secretKey: await _key());
    directory.createSync(recursive: true);
    await File('${directory.path}${Platform.pathSeparator}$name').writeAsBytes(box.concatenation(), flush: true);
    return name;
  }

  Future<Uint8List> readRecording(String name) async {
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    final box = SecretBox.fromConcatenation(
      await file.readAsBytes(),
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await algorithm.decrypt(box, secretKey: await _key()));
  }

  Future<void> dropRecording(String name) async {
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    if (file.existsSync()) await file.delete();
  }

  Future<void> removeAt(int index) async {
    final entries = await load();
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await replace(entries);
  }

  Future<void> clear() => replace([]);

  Future<void> replace(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) {
      if (_file.existsSync()) await _file.delete();
      return;
    }
    final clear = utf8.encode(jsonEncode(entries));
    final box = await algorithm.encrypt(clear, secretKey: await _key());
    directory.createSync(recursive: true);
    await _file.writeAsBytes(box.concatenation(), flush: true);
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (!_file.existsSync() || _file.lengthSync() == 0) return [];
    final box = SecretBox.fromConcatenation(
      await _file.readAsBytes(),
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    final clear = await algorithm.decrypt(box, secretKey: await _key());
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! List) return [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<SecretKey> _key() async {
    final existing = await secrets.read(AtRestCipher.historyKeyName);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }
    final legacy = legacyPreferences?.getString(legacyKeyPreference);
    if (legacy != null && legacy.isNotEmpty) {
      await secrets.write(AtRestCipher.historyKeyName, legacy);
      await legacyPreferences?.remove(legacyKeyPreference);
      return SecretKey(base64Decode(legacy));
    }
    final created = await algorithm.newSecretKey();
    final bytes = Uint8List.fromList(await created.extractBytes());
    await secrets.write(AtRestCipher.historyKeyName, base64Encode(bytes));
    return SecretKey(bytes);
  }
}
