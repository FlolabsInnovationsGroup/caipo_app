import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:caipo_app/core/config/app_paths.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/core/security/at_rest.dart';
import 'package:caipo_app/core/security/secret_store.dart';
import 'package:caipo_app/device/protocol/transfer_archive.dart';
import 'package:caipo_app/device/wifi/wifi_networks.dart';
import 'package:caipo_app/features/auth/biometric_gate.dart';
import 'package:caipo_app/features/auth/session_controller.dart';
import 'package:caipo_app/features/conversation/history_store.dart';
import 'package:caipo_app/features/privacy/local_data.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a history key in preferences moves into the secure store', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final key = base64Encode(List<int>.filled(32, 9));
    await prefs.setString(ConversationHistoryStore.legacyKeyPreference, key);
    final secrets = SecretStore.memory();
    final directory = Directory.systemTemp.createTempSync('caipo-migrate');
    final store = ConversationHistoryStore(directory: directory, secrets: secrets, legacyPreferences: prefs);
    await store.append(role: 'user', text: 'still here');
    expect(prefs.getString(ConversationHistoryStore.legacyKeyPreference), isNull);
    expect(await secrets.read(AtRestCipher.historyKeyName), key);
    expect((await store.load()).single['text'], 'still here');
    directory.deleteSync(recursive: true);
  });

  test('biometric unlock stays off until the setting is turned on', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(
      FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true),
      prefs,
    );
    final session = SessionController(
      auth: AuthRepository(
        FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true),
      ),
      settings: settings,
      preferences: prefs,
      logger: const AppLogger(),
    );
    session.signedIn = true;
    session.locked = true;
    expect(settings.biometricUnlock(), isFalse);
    expect(showBiometricUnlock(locked: session.locked, enabled: settings.biometricUnlock()), isFalse);
    await settings.setBiometricUnlock(true);
    expect(settings.biometricUnlock(), isTrue);
    expect(showBiometricUnlock(locked: session.locked, enabled: true), isTrue);
    session.unlock();
    expect(session.locked, isFalse);
    await settings.setBiometricUnlock(false);
    session.locked = true;
    expect(settings.biometricUnlock(), isFalse);
    expect(showBiometricUnlock(locked: session.locked, enabled: settings.biometricUnlock()), isFalse);
  });

  test('an open app locks after the auto-lock limit with no touches', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true);
    final settings = SettingsRepository(api, prefs);
    var now = DateTime.utc(2026, 10, 22, 9);
    final session = SessionController(
      auth: AuthRepository(api),
      settings: settings,
      preferences: prefs,
      logger: const AppLogger(),
      clock: () => now,
    );
    await session.signIn('ada@example.com', 'secret');

    now = now.add(Duration(minutes: settings.autoLockMinutes() - 1));
    session.checkIdle();
    expect(session.locked, isFalse);

    await session.noteActivity();
    now = now.add(Duration(minutes: settings.autoLockMinutes()));
    session.checkIdle();
    expect(session.locked, isTrue);
  });

  test('export is the conversation and not the Wi-Fi password', () async {
    final secrets = SecretStore.memory();
    final directory = Directory.systemTemp.createTempSync('caipo-export');
    final history = ConversationHistoryStore(directory: directory, secrets: secrets);
    await history.append(role: 'user', text: 'hello from the glasses');
    final privacy = _privacy(history: history, secrets: secrets, directory: directory);
    final exported = jsonDecode(await privacy.export()) as Map<String, dynamic>;
    final conversation = exported['conversation'] as List<dynamic>;
    expect(conversation.single['text'], 'hello from the glasses');
    expect(exported.containsKey('exportedAt'), isTrue);
    expect(jsonEncode(exported).contains('hotspot-secret'), isFalse);
    directory.deleteSync(recursive: true);
  });

  test('delete all local data removes keys, media, Wi-Fi, and history, then signs out', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = SecretStore.memory();
    final root = Directory.systemTemp.createTempSync('caipo-wipe');
    final paths = AppPaths(
      documents: root,
      transfers: Directory('${root.path}${Platform.pathSeparator}transfers')..createSync(),
      replies: Directory('${root.path}${Platform.pathSeparator}replies')..createSync(),
      history: Directory('${root.path}${Platform.pathSeparator}history')..createSync(),
      playback: Directory('${root.path}${Platform.pathSeparator}playback')..createSync(),
    );
    final history = ConversationHistoryStore(directory: paths.history, secrets: secrets);
    await history.append(role: 'user', text: 'private');
    await writePlaybackCopy(paths.playback, 'reply.wav', Uint8List.fromList([7]));
    await prefs.setBool('caipo.onboarded', true);
    await AtRestCipher(secrets: secrets, keyName: AtRestCipher.mediaKeyName).seal(Uint8List.fromList([1, 2, 3]));
    await File('${paths.transfers.path}${Platform.pathSeparator}clip.bin').writeAsBytes([4, 5]);
    await File('${paths.replies.path}${Platform.pathSeparator}reply.wav').writeAsBytes([6]);
    var wifiRaw = jsonEncode([
      {'ssid': 'home', 'password': 'hotspot-secret', 'phoneHotspot': false},
    ]);
    final wifi = WifiNetworkStore(
      read: () async => wifiRaw,
      write: (value) async => wifiRaw = value,
    );
    final tokens = MemoryTokenStore();
    final api = FloBrainApi(tokenStore: tokens, logger: const AppLogger(), mockBackend: true);
    final session = SessionController(
      auth: AuthRepository(api),
      settings: SettingsRepository(api, prefs),
      preferences: prefs,
      logger: const AppLogger(),
    );
    await session.signIn('ada@example.com', 'secret');
    expect(session.signedIn, isTrue);
    final privacy = PrivacyActions(
      history: history,
      secrets: secrets,
      paths: paths,
      wifi: wifi,
      wipeStore: tokens.clear,
      preferences: prefs,
    );
    await privacy.deleteAll();
    await session.signOut();
    expect(await history.load(), isEmpty);
    expect(paths.transfers.listSync(), isEmpty);
    expect(paths.replies.listSync(), isEmpty);
    expect(paths.playback!.listSync(), isEmpty);
    expect(prefs.getKeys(), isEmpty);
    expect(await secrets.read(AtRestCipher.historyKeyName), isNull);
    expect(await secrets.read(AtRestCipher.mediaKeyName), isNull);
    expect(await wifi.load(), isEmpty);
    expect(await tokens.read(), isNull);
    expect(session.signedIn, isFalse);
    root.deleteSync(recursive: true);
  });

  test('a transfer that arrives in the background is sealed before it is written', () async {
    final secrets = SecretStore.memory();
    final cipher = AtRestCipher(secrets: secrets, keyName: AtRestCipher.mediaKeyName);
    final directory = Directory.systemTemp.createTempSync('caipo-bg');
    final archive = TransferArchive(directory, cipher: cipher);
    final plain = Uint8List.fromList([9, 8, 7, 6]);
    final saved = await archive.save(bytes: plain, contentType: 1);
    final partial = await archive.savePartial(Uint8List.fromList([3, 3]));
    final stored = await saved.readAsBytes();
    final held = await partial.readAsBytes();
    expect(cipher.isSealed(stored), isTrue);
    expect(cipher.isSealed(held), isTrue);
    expect(stored, isNot(plain));
    expect(await cipher.open(stored), plain);
    expect(await cipher.open(held), [3, 3]);
    directory.deleteSync(recursive: true);
  });
}

PrivacyActions _privacy({
  required ConversationHistoryStore history,
  required SecretStore secrets,
  required Directory directory,
}) {
  return PrivacyActions(
    history: history,
    secrets: secrets,
    paths: AppPaths(
      documents: directory,
      transfers: directory,
      replies: directory,
      history: directory,
    ),
    wifi: WifiNetworkStore(read: () async => null, write: (_) async {}),
    wipeStore: () async {},
  );
}
