import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/ble/ble_bridge.dart';
import 'package:caipo_app/device/ble/connection.dart';
import 'package:caipo_app/device/ble/known_device_store.dart';
import 'package:caipo_app/device/ble/scanner.dart';
import 'package:caipo_app/features/auth/session_controller.dart';
import 'package:caipo_app/features/pairing/pairing_controller.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/auth_repository.dart';
import 'package:caipo_app/flobrain/chat_repository.dart';
import 'package:caipo_app/flobrain/memory_repository.dart';
import 'package:caipo_app/flobrain/profile_repository.dart';
import 'package:caipo_app/flobrain/secure_token_store.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/gen/secure_store_api.g.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  final logger = const AppLogger();
  getIt
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerLazySingleton<BleBridge>(BleBridge.new)
    ..registerLazySingleton<SecureTokenStore>(() => SecureTokenStore(SecureStoreHostApi()))
    ..registerLazySingleton<FloBrainApi>(
      () => FloBrainApi(tokenStore: getIt<SecureTokenStore>(), logger: logger),
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
    ..registerLazySingleton<SessionController>(
      () => SessionController(
        auth: getIt<AuthRepository>(),
        settings: getIt<SettingsRepository>(),
        preferences: preferences,
        logger: logger,
      ),
    )
    ..registerLazySingleton<PairingController>(
      () => PairingController(
        bridge: getIt<BleBridge>(),
        scanner: getIt<DeviceScanner>(),
        connection: getIt<DeviceConnection>(),
        knownDevices: getIt<KnownDeviceStore>(),
        logger: logger,
      ),
    );
}
