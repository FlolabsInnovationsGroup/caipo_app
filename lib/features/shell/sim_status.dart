import '../../device/device_state.dart';

/// Copy for the simulated device. It follows the link, so a connected
/// session does not keep the "connect to CAIPO-SIM" line.
String simulatedDeviceStatus({
  required CaipoLinkState link,
  required bool scanning,
  String? voiceLabel,
}) {
  if (link == CaipoLinkState.connected) {
    if (voiceLabel == null || voiceLabel.isEmpty) return 'Connected to CAIPO-SIM.';
    return 'Connected to CAIPO-SIM. $voiceLabel.';
  }
  if (link == CaipoLinkState.reconnecting) return 'Reconnecting to the simulated device.';
  if (link == CaipoLinkState.connecting) return 'Connecting to the simulated device.';
  if (scanning || link == CaipoLinkState.scanning) return 'Scanning for the simulated device.';
  if (link == CaipoLinkState.pairingFailed) return 'Pairing the simulated device failed.';
  if (link == CaipoLinkState.notFound) return 'No simulated device found.';
  return 'Simulated CAIPO. Connect to CAIPO-SIM to run the voice loop.';
}

String linkStatusLabel(CaipoLinkState state) {
  switch (state) {
    case CaipoLinkState.disconnected:
      return 'Not connected';
    case CaipoLinkState.scanning:
      return 'Scanning';
    case CaipoLinkState.notFound:
      return 'No device found';
    case CaipoLinkState.connecting:
      return 'Connecting';
    case CaipoLinkState.pairingFailed:
      return 'Pairing failed';
    case CaipoLinkState.connected:
      return 'Connected';
    case CaipoLinkState.reconnecting:
      return 'Reconnecting';
    case CaipoLinkState.listening:
      return 'Listening';
    case CaipoLinkState.processing:
      return 'Processing';
    case CaipoLinkState.responding:
      return 'Responding';
  }
}
