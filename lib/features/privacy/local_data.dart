import 'dart:convert';
import 'dart:io';

import '../../core/config/app_paths.dart';
import '../../core/security/at_rest.dart';
import '../../core/security/secret_store.dart';
import '../../device/wifi/wifi_networks.dart';
import '../conversation/history_store.dart';

/// Export and full local deletion. Tokens and Wi-Fi passwords are not exported.
class LocalData {
  const LocalData();

  Future<String> exportJson(ConversationHistoryStore history) async {
    final entries = await history.load();
    return jsonEncode({
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'conversation': entries,
    });
  }

  Future<void> deleteAll({
    required AppPaths paths,
    required ConversationHistoryStore history,
    required SecretStore secrets,
    required WifiNetworkStore wifi,
  }) async {
    await history.clear();
    await _empty(paths.history);
    await _empty(paths.transfers);
    await _empty(paths.replies);
    await secrets.delete(AtRestCipher.historyKeyName);
    await secrets.delete(AtRestCipher.mediaKeyName);
    await wifi.write('[]');
  }

  Future<void> _empty(Directory directory) async {
    if (!directory.existsSync()) return;
    for (final entity in directory.listSync()) {
      await entity.delete(recursive: true);
    }
  }
}

class PrivacyActions {
  PrivacyActions({
    required this.history,
    required this.secrets,
    required this.paths,
    required this.wifi,
    required this.wipeStore,
  });

  final ConversationHistoryStore history;
  final SecretStore secrets;
  final AppPaths paths;
  final WifiNetworkStore wifi;

  /// Production passes the secure-store wipe, which removes tokens as well as any leftover keys.
  final Future<void> Function() wipeStore;

  Future<String> export() => const LocalData().exportJson(history);

  Future<void> deleteAll() async {
    await const LocalData().deleteAll(paths: paths, history: history, secrets: secrets, wifi: wifi);
    await wipeStore();
  }
}
