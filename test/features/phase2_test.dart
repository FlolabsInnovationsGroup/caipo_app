import 'dart:convert';
import 'dart:io';

import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/device_state.dart';
import 'package:caipo_app/core/security/at_rest.dart';
import 'package:caipo_app/core/security/secret_store.dart';
import 'package:caipo_app/features/conversation/history_store.dart';
import 'package:caipo_app/features/conversation/voice_loop.dart';
import 'package:caipo_app/features/shell/led_state.dart';
import 'package:caipo_app/features/shell/sim_status.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:caipo_app/shared/theme/caipo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('simulated status follows the link', () {
    expect(
      simulatedDeviceStatus(link: CaipoLinkState.disconnected, scanning: false),
      'Simulated CAIPO. Connect to CAIPO-SIM to run the voice loop.',
    );
    expect(
      simulatedDeviceStatus(link: CaipoLinkState.connected, scanning: false),
      'Connected to CAIPO-SIM.',
    );
    expect(
      simulatedDeviceStatus(link: CaipoLinkState.connected, scanning: false, voiceLabel: 'Listening'),
      'Connected to CAIPO-SIM. Listening.',
    );
    expect(
      simulatedDeviceStatus(link: CaipoLinkState.connecting, scanning: false),
      'Connecting to the simulated device.',
    );
  });

  test('LED colors match the listed states', () {
    expect(CaipoPalette.ledStandby, const Color(0xFF2F6FED));
    expect(CaipoPalette.ledBoot, const Color(0xFFF7F7F5));
    expect(CaipoPalette.ledVideo, const Color(0xFF2E9B4F));
    expect(CaipoPalette.ledAudio, const Color(0xFFE2B100));
    expect(CaipoPalette.ledAlert, const Color(0xFFD23B3B));
    expect(CaipoPalette.ledCharging, const Color(0xFF21B7C5));
    expect(CaipoPalette.ledProcessing, const Color(0xFF7A4DDB));
    expect(
      currentLed(
        link: CaipoLinkState.connected,
        phase: VoicePhase.processing,
        failed: false,
      ).color,
      CaipoPalette.ledProcessing,
    );
    expect(
      currentLed(
        link: CaipoLinkState.connected,
        phase: VoicePhase.listening,
        failed: false,
      ).color,
      CaipoPalette.ledAudio,
    );
    expect(
      currentLed(
        link: CaipoLinkState.connected,
        phase: VoicePhase.idle,
        failed: false,
        batteryPercent: 10,
      ).color,
      CaipoPalette.ledAlert,
    );
  });

  test('auto-lock stays inside 1 to 30 and defaults to 15', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(
      FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true),
      prefs,
    );
    expect(settings.autoLockMinutes(), 15);
    await settings.setAutoLockMinutes(60);
    expect(settings.autoLockMinutes(), 30);
    expect(prefs.getInt(SettingsRepository.autoLockKey), 30);
    await settings.setAutoLockMinutes(0);
    expect(settings.autoLockMinutes(), 1);
  });

  test('history can drop one message or all of them', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final directory = Directory.systemTemp.createTempSync('caipo-history');
    final secrets = SecretStore.memory();
    final key = base64Encode(List<int>.filled(32, 7));
    await prefs.setString(ConversationHistoryStore.legacyKeyPreference, key);
    final store = ConversationHistoryStore(directory: directory, secrets: secrets, legacyPreferences: prefs);
    await store.append(role: 'user', text: 'hello');
    await store.append(role: 'assistant', text: 'reply');
    await store.removeAt(0);
    final left = await store.load();
    expect(left, hasLength(1));
    expect(left.single['text'], 'reply');
    await store.clear();
    expect(await store.load(), isEmpty);
    expect(await secrets.read(AtRestCipher.historyKeyName), key);
    expect(prefs.getString(ConversationHistoryStore.legacyKeyPreference), isNull);
    directory.deleteSync(recursive: true);
  });
}
