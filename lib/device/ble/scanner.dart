import 'dart:async';

import '../../core/config/constants.dart';
import 'ble_bridge.dart';

class SeenDevice {
  const SeenDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });

  final String id;
  final String name;
  final int rssi;
  final List<String> serviceUuids;
}

bool caipoAdvertisementMatches({
  required String name,
  required List<String> serviceUuids,
}) {
  final prefix = kAdvertisedNamePrefix.toLowerCase();
  if (name.isNotEmpty) {
    return name.toLowerCase().startsWith(prefix);
  }
  final target = kPrimaryServiceUuid.toLowerCase();
  return serviceUuids.any((uuid) => uuid.toLowerCase() == target);
}

class DeviceScanner {
  DeviceScanner(this.bridge);

  final BleBridge bridge;
  StreamSubscription<dynamic>? _sub;

  bool matchesCaipo(SeenDevice device) => caipoAdvertisementMatches(
        name: device.name,
        serviceUuids: device.serviceUuids,
      );

  Future<List<SeenDevice>> scan({int timeoutSeconds = kScanTimeoutSeconds}) async {
    final found = <String, SeenDevice>{};
    final completer = Completer<void>();
    _sub = bridge.discoveries.stream.listen((peripheral) {
      final device = SeenDevice(
        id: peripheral.uuid,
        name: peripheral.name,
        rssi: peripheral.rssi,
        serviceUuids: peripheral.serviceUuids,
      );
      if (!matchesCaipo(device)) return;
      found[device.id] = device;
    });
    try {
      await bridge.controller.startScan(timeoutSeconds, [kPrimaryServiceUuid]);
      await Future<void>.delayed(Duration(seconds: timeoutSeconds));
      if (!completer.isCompleted) completer.complete();
      await completer.future;
    } finally {
      try {
        await bridge.controller.stopScan();
      } catch (_) {}
      await _sub?.cancel();
      _sub = null;
    }
    final devices = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return devices;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await bridge.controller.stopScan();
  }
}
