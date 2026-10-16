import 'dart:io';

import 'package:caipo_app/core/config/app_mode.dart';
import 'package:caipo_app/core/config/app_paths.dart';
import 'package:caipo_app/core/config/proposed_flags.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:caipo_app/device/ble/ble_bridge.dart';
import 'package:caipo_app/device/ble/connection.dart';
import 'package:caipo_app/device/ble/known_device_store.dart';
import 'package:caipo_app/device/ble/scanner.dart';
import 'package:caipo_app/device/protocol/transfer_archive.dart';
import 'package:caipo_app/core/security/at_rest.dart';
import 'package:caipo_app/core/security/secret_store.dart';
import 'package:caipo_app/features/auth/biometric_gate.dart';
import 'package:caipo_app/features/auth/session_controller.dart';
import 'package:caipo_app/features/conversation/history_store.dart';
import 'package:caipo_app/features/privacy/local_data.dart';
import 'package:caipo_app/features/conversation/voice_loop.dart';
import 'package:caipo_app/features/notifications/notification_center.dart';
import 'package:caipo_app/features/pairing/pairing_controller.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/memory_repository.dart';
import 'package:caipo_app/flobrain/profile_repository.dart';
import 'package:caipo_app/device/sim/sim_caipo_controller.dart';
import 'package:caipo_app/device/wifi/wifi_networks.dart';
import 'package:caipo_app/device/wifi/wifi_sender.dart';
import 'package:caipo_app/flobrain/secure_token_store.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/flobrain/proposed_clients.dart';
import 'package:caipo_app/flobrain/speech_clients.dart';
import 'package:caipo_app/gen/secure_store_api.g.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  final logger = const AppLogger();
  final documents = await getApplicationDocumentsDirectory();
  final transfers = Directory('${documents.path}${Platform.pathSeparator}transfers');
  final historyDir = Directory('${documents.path}${Platform.pathSeparator}history');
  final replies = Directory('${documents.path}${Platform.pathSeparator}sim-replies');
  transfers.createSync(recursive: true);
  historyDir.createSync(recursive: true);
  replies.createSync(recursive: true);
  final paths = AppPaths(documents: documents, transfers: transfers, replies: replies, history: historyDir);
  final secureApi = SecureStoreHostApi();
  final secrets = SecretStore.platform(secureApi);
  final history = ConversationHistoryStore(
    directory: historyDir,
    secrets: secrets,
    legacyPreferences: preferences,
  );
  final mediaCipher = AtRestCipher(secrets: secrets, keyName: AtRestCipher.mediaKeyName);
  final archive = TransferArchive(transfers, cipher: mediaCipher);
  getIt
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerSingleton<AppPaths>(paths)
    ..registerLazySingleton<BleBridge>(
      () => useSimulatedDevice ? SimCaipoController.open(replyDirectory: replies) : BleBridge(),
    )
    ..registerSingleton<SecretStore>(secrets)
    ..registerSingleton<ConversationHistoryStore>(history)
    ..registerLazySingleton<SecureTokenStore>(() => SecureTokenStore(secureApi))
    ..registerLazySingleton<FloBrainApi>(
      () => FloBrainApi(
        tokenStore: getIt<SecureTokenStore>(),
        logger: logger,
        mockBackend: useMockBackend,
      ),
    )
    ..registerLazySingleton<AuthRepository>(() => AuthRepository(getIt<FloBrainApi>()))
    ..registerLazySingleton<ProfileRepository>(() => ProfileRepository(getIt<FloBrainApi>()))
    ..registerLazySingleton<ChatRepository>(() => ChatRepository(getIt<FloBrainApi>()))
    ..registerLazySingleton<MemoryRepository>(() => MemoryRepository(getIt<FloBrainApi>()))
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(getIt<FloBrainApi>(), preferences),
    )
    ..registerLazySingleton<KnownDeviceStore>(() => KnownDeviceStore(preferences))
    ..registerLazySingleton<DeviceScanner>(() => DeviceScanner(getIt<BleBridge>()))
    ..registerLazySingleton<DeviceConnection>(() => DeviceConnection(getIt<BleBridge>(), logger))
    ..registerLazySingleton<SpeechClient>(() {
      if (useMockBackend) return const MockSpeechClient();
      if (kProposedSpeech) return ProposedSpeechClient(getIt<FloBrainApi>());
      return const UnavailableSpeechClient();
    })
    ..registerLazySingleton<FloBrainMediaClient>(() => FloBrainMediaClient(getIt<FloBrainApi>()))
    ..registerLazySingleton<WifiNetworkStore>(() {
      return WifiNetworkStore(
        read: () => secureApi.read('caipo.wifi.networks'),
        write: (value) => secureApi.write('caipo.wifi.networks', value),
      );
    })
    ..registerLazySingleton<WifiSender>(
      () => WifiSender(connection: getIt<DeviceConnection>(), bridge: getIt<BleBridge>()),
    )
    ..registerLazySingleton<VoiceLoopController>(() {
      final loop = VoiceLoopController(
        connection: getIt<DeviceConnection>(),
        bridge: getIt<BleBridge>(),
        chats: getIt<ChatRepository>(),
        speech: getIt<SpeechClient>(),
        archive: archive,
        history: history,
        logger: logger,
        codec: OpusCodec.shared,
      );
      final sim = getIt<BleBridge>().controller;
      if (sim is SimCaipoController) sim.onReplySaved = loop.noteReplyWav;
      return loop;
    })
    ..registerLazySingleton<NotificationCenter>(() => NotificationCenter(preferences, logger: logger))
    ..registerLazySingleton<SessionController>(
      () => SessionController(
        auth: getIt<AuthRepository>(),
        settings: getIt<SettingsRepository>(),
        preferences: preferences,
        logger: logger,
      ),
    )
    ..registerLazySingleton<BiometricGate>(BiometricGate.new)
    ..registerLazySingleton<PrivacyActions>(
      () => PrivacyActions(
        history: history,
        secrets: secrets,
        paths: paths,
        wifi: getIt<WifiNetworkStore>(),
        wipeStore: getIt<SecureTokenStore>().deleteAll,
      ),
    )
    ..registerLazySingleton<PairingController>(
      () => PairingController(
        bridge: getIt<BleBridge>(),
        scanner: getIt<DeviceScanner>(),
        connection: getIt<DeviceConnection>(),
        knownDevices: getIt<KnownDeviceStore>(),
        logger: logger,
        voice: getIt<VoiceLoopController>(),
        archive: archive,
        autoConnect: () => getIt<SettingsRepository>().autoConnect(),
      ),
    );
}
