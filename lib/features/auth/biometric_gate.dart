import 'package:local_auth/local_auth.dart';

/// The lock screen offers biometrics only when the setting is on and the session is locked.
bool showBiometricUnlock({required bool locked, required bool enabled}) => locked && enabled;

/// Optional unlock. Password sign-in stays available when this is off or fails.
class BiometricGate {
  BiometricGate({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> available() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.canCheckBiometrics;
      return supported && enrolled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock CAIPO',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
