/// Switches set at build time:
/// `flutter run --dart-define=DEVICE_MODE=sim --dart-define=BACKEND_MODE=mock`
///
/// `sim` is the in-app device. `ble` is the real radio.
/// `mock` never opens a socket. `live` calls `https://api.flobrain.ai`.
enum DeviceMode { sim, ble }

enum BackendMode { mock, live }

const String _deviceModeName = String.fromEnvironment('DEVICE_MODE', defaultValue: 'ble');
const String _backendModeName = String.fromEnvironment('BACKEND_MODE', defaultValue: 'live');

DeviceMode get deviceMode => _deviceModeName == 'sim' ? DeviceMode.sim : DeviceMode.ble;

BackendMode get backendMode => _backendModeName == 'mock' ? BackendMode.mock : BackendMode.live;

bool get useSimulatedDevice => deviceMode == DeviceMode.sim;

bool get useMockBackend => backendMode == BackendMode.mock;
