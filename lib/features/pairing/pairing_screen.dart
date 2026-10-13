import 'package:flutter/material.dart';

import '../../device/ble/pairing_failure.dart';
import '../../device/device_state.dart';
import '../../flobrain/settings_repository.dart';
import '../auth/session_controller.dart';
import 'pairing_controller.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({
    super.key,
    required this.session,
    required this.pairing,
    required this.settings,
  });

  final SessionController session;
  final PairingController pairing;
  final SettingsRepository settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pairing,
      builder: (context, _) {
        final failure = pairing.failure;
        return Scaffold(
          appBar: AppBar(
            title: const Text('CAIPO'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: pairing.scanning ? null : pairing.refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: session.signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_statusLabel(pairing.link), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Bluetooth: ${pairing.bluetoothState}'),
              if (failure != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(failure.title, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(failure.message),
                        if (failure.opensSettings)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                if (failure == PairingFailure.bluetoothOff) {
                                  await pairing.enableBluetooth();
                                }
                                await pairing.openSettings();
                              },
                              child: const Text('Open settings'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: settings.autoLockMinutes(),
                items: const [1, 5, 15, 60]
                    .map((minutes) => DropdownMenuItem(value: minutes, child: Text('Auto-lock after $minutes min')))
                    .toList(),
                onChanged: (minutes) async {
                  if (minutes == null) return;
                  await settings.setAutoLockMinutes(minutes);
                  await session.noteActivity();
                },
              ),
              const SizedBox(height: 8),
              if (pairing.scanning) const LinearProgressIndicator(),
              if (pairing.devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No devices yet. Refresh to scan, or reconnect a device you have paired before.'),
                ),
              for (final device in pairing.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name.isEmpty ? 'Unnamed device' : device.name),
                  subtitle: Text(
                    [
                      if (device.nearby) 'Nearby' else 'Saved',
                      if (device.rssi != null) '${device.rssi} dBm',
                      if (device.batteryPercent != null) 'Battery ${device.batteryPercent}%',
                      if (pairing.connectedId == device.id) 'Connected',
                    ].join(' · '),
                  ),
                  trailing: pairing.connectedId == device.id
                      ? IconButton(
                          tooltip: 'Forget',
                          onPressed: () => pairing.forget(device.id),
                          icon: const Icon(Icons.link_off),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: pairing.connectedId == device.id ? null : () => pairing.connect(device.id, device.name),
                ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(CaipoLinkState state) {
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
}
