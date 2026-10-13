enum PairingFailure {
  bluetoothOff,
  bluetoothUnauthorized,
  bluetoothUnsupported,
  permissionDenied,
  locationPermissionDenied,
  notificationPermissionDenied,
  scanFailed,
  notFound,
  connectTimeout,
  gattDiscoveryFailed,
  serviceMissing,
  bondFailed,
  linkLost,
  reconnectExhausted,
  adapterUnavailable,
  cancelled,
}

extension PairingFailureMessage on PairingFailure {
  String get title {
    switch (this) {
      case PairingFailure.bluetoothOff:
        return 'Bluetooth is off';
      case PairingFailure.bluetoothUnauthorized:
        return 'Bluetooth permission needed';
      case PairingFailure.bluetoothUnsupported:
        return 'Bluetooth LE is unavailable';
      case PairingFailure.permissionDenied:
        return 'Bluetooth permission denied';
      case PairingFailure.locationPermissionDenied:
        return 'Location permission needed to scan';
      case PairingFailure.notificationPermissionDenied:
        return 'Notifications are off';
      case PairingFailure.scanFailed:
        return 'Scan failed';
      case PairingFailure.notFound:
        return 'No CAIPO device found';
      case PairingFailure.connectTimeout:
        return 'Connection timed out';
      case PairingFailure.gattDiscoveryFailed:
        return 'Service discovery failed';
      case PairingFailure.serviceMissing:
        return 'This device is not advertising CAIPO';
      case PairingFailure.bondFailed:
        return 'Pairing was rejected';
      case PairingFailure.linkLost:
        return 'Connection lost';
      case PairingFailure.reconnectExhausted:
        return 'Could not reconnect';
      case PairingFailure.adapterUnavailable:
        return 'Bluetooth adapter unavailable';
      case PairingFailure.cancelled:
        return 'Connection cancelled';
    }
  }

  String get message {
    switch (this) {
      case PairingFailure.bluetoothOff:
        return 'Turn Bluetooth on to find your CAIPO. You can open system settings from here.';
      case PairingFailure.bluetoothUnauthorized:
        return 'Allow Bluetooth for CAIPO in system settings, then come back and refresh.';
      case PairingFailure.bluetoothUnsupported:
        return 'This phone does not expose a Bluetooth Low Energy radio, so CAIPO cannot pair.';
      case PairingFailure.permissionDenied:
        return 'CAIPO needs Bluetooth scan and connect permission. Open settings and allow both.';
      case PairingFailure.locationPermissionDenied:
        return 'Android 10 and 11 require location permission to scan for Bluetooth devices. Allow location, then refresh.';
      case PairingFailure.notificationPermissionDenied:
        return 'Allow notifications so Android can keep the CAIPO connection alive while the app is in the background.';
      case PairingFailure.scanFailed:
        return 'The Bluetooth scan did not start. Confirm Bluetooth is on and the permissions above are allowed, then refresh.';
      case PairingFailure.notFound:
        return 'No nearby device advertised the CAIPO service. Move closer, wake the device, and refresh.';
      case PairingFailure.connectTimeout:
        return 'The device did not finish connecting. Stay close to it and try again.';
      case PairingFailure.gattDiscoveryFailed:
        return 'The phone connected, then service discovery failed. Try again. If it keeps happening, the firmware GATT table may not be ready.';
      case PairingFailure.serviceMissing:
        return 'The device connected, but the CAIPO service was not in its GATT table. The service UUID is still a development placeholder, so this can also mean the firmware is not advertising CAIPO yet.';
      case PairingFailure.bondFailed:
        return 'The system pairing dialog did not complete. Try again and accept the pairing request.';
      case PairingFailure.linkLost:
        return 'The link dropped. CAIPO will try to reconnect in 1s, then 2s, then 4s.';
      case PairingFailure.reconnectExhausted:
        return 'Reconnection failed after waits of 1s, 2s and 4s. Move closer to the device and pair again.';
      case PairingFailure.adapterUnavailable:
        return 'The Bluetooth adapter is not ready yet. Wait a moment and refresh.';
      case PairingFailure.cancelled:
        return 'The connection was cancelled.';
    }
  }

  bool get opensSettings {
    switch (this) {
      case PairingFailure.bluetoothOff:
      case PairingFailure.bluetoothUnauthorized:
      case PairingFailure.permissionDenied:
      case PairingFailure.locationPermissionDenied:
      case PairingFailure.notificationPermissionDenied:
        return true;
      default:
        return false;
    }
  }
}

PairingFailure? failureFromNativeError(String? error) {
  switch (error) {
    case null:
    case '':
    case 'link_lost':
      return PairingFailure.linkLost;
    case 'timeout':
      return PairingFailure.connectTimeout;
    case 'gatt_discovery_failed':
      return PairingFailure.gattDiscoveryFailed;
    case 'bond_failed':
      return PairingFailure.bondFailed;
    case 'cancelled':
      return PairingFailure.cancelled;
    case 'bluetooth_off':
      return PairingFailure.bluetoothOff;
    case 'permission_denied':
      return PairingFailure.permissionDenied;
    default:
      return PairingFailure.adapterUnavailable;
  }
}
