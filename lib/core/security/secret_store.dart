import '../../gen/secure_store_api.g.dart';

/// A string secret in the iOS Keychain or the Android Keystore.
class SecretStore {
  const SecretStore({required this.read, required this.write, required this.delete});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) delete;

  /// In-memory store for tests. The app build uses [platform].
  factory SecretStore.memory() {
    final values = <String, String>{};
    return SecretStore(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
      delete: (key) async => values.remove(key),
    );
  }

  factory SecretStore.platform(SecureStoreHostApi api) {
    return SecretStore(read: api.read, write: api.write, delete: api.delete);
  }
}
