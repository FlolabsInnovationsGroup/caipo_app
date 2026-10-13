class WifiProvisionResult {
  const WifiProvisionResult.mock(this.detail);

  final String detail;
  final bool sent = false;
}

/// Phase 6 mock. Credentials are not written over BLE.
class WifiProvisioner {
  const WifiProvisioner();

  Future<WifiProvisionResult> sendCredentials({
    required String ssid,
    required String password,
  }) async {
    return const WifiProvisionResult.mock(
      'Wi-Fi provisioning is not in this build. BLE stays the always-on '
      'channel; credentials were not sent.',
    );
  }
}
