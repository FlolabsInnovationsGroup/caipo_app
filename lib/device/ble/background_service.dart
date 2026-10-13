import '../../core/config/constants.dart';

/// Background connection maintenance is native.
///
/// Android starts a connected-device foreground service inside manageDevice.
/// iOS uses the bluetooth-central background mode and state restoration
/// ([kBleRestoreIdentifier]). This type is the Dart-side record of that
/// contract so the rest of the app does not grow a second connection owner.
class BackgroundConnection {
  const BackgroundConnection();

  String get restoreIdentifier => kBleRestoreIdentifier;

  bool get keepsBleAlwaysOn => true;
}
