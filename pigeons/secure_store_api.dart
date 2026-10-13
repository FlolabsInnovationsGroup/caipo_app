import 'package:pigeon/pigeon.dart';

/// Keychain (iOS) and Android Keystore (Android) token storage.
///
/// Ciphertext on Android is written to an app-private file. Tokens are never
/// written to SharedPreferences.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/gen/secure_store_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/SecureStoreApi.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut: 'android/app/src/main/kotlin/com/flolabs/caipo/SecureStoreApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.flolabs.caipo'),
  ),
)
@HostApi()
abstract class SecureStoreHostApi {
  @async
  void write(String key, String value);

  @async
  String? read(String key);

  @async
  void delete(String key);

  @async
  void deleteAll();
}
