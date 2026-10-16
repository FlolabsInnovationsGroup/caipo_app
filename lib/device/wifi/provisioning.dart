import 'dart:convert';
import 'dart:typed_data';

import '../../core/config/proposed_flags.dart';
import 'wifi_networks.dart';

class WifiProvisionResult {
  const WifiProvisionResult({required this.sent, required this.detail});

  final bool sent;
  final String detail;
}

/// Sends the proposed Wi-Fi list as one R03 payload. Off by default.
///
/// Credentials are written only when the flag is on and the link is bonded.
class WifiProvisioner {
  const WifiProvisioner({this.enabled = kProposedWifi});

  final bool enabled;

  Future<WifiProvisionResult> send({
    required List<WifiNetwork> networks,
    required String deviceToken,
    required bool bonded,
    required Future<void> Function(Uint8List payload) writePayload,
  }) async {
    if (!enabled) {
      return const WifiProvisionResult(
        sent: false,
        detail: 'Wi-Fi provisioning is proposed and turned off. Nothing was sent.',
      );
    }
    if (!bonded) {
      return const WifiProvisionResult(
        sent: false,
        detail: 'Wi-Fi credentials are only sent over a bonded link. Nothing was sent.',
      );
    }
    if (networks.isEmpty) {
      return const WifiProvisionResult(sent: false, detail: 'Add a network before sending.');
    }
    final body = jsonEncode({
      'networks': [
        for (final network in networks.take(WifiNetworkStore.maxNetworks))
          {'ssid': network.ssid, 'password': network.password},
      ],
      'device_token': deviceToken,
    });
    await writePayload(Uint8List.fromList(utf8.encode(body)));
    return const WifiProvisionResult(sent: true, detail: 'The network list was handed to the transfer.');
  }
}
