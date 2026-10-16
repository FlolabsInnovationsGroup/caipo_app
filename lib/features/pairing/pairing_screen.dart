import 'package:flutter/material.dart';

import '../../core/config/app_mode.dart';
import '../../device/ble/pairing_failure.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../shell/sim_status.dart';
import 'pairing_controller.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key, required this.pairing});

  final PairingController pairing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pairing,
      builder: (context, _) {
        final failure = pairing.failure;
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.pair),
            actions: [
              IconButton(
                tooltip: AppStrings.refresh,
                onPressed: () {
                  if (pairing.scanning) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Still looking for CAIPO.')),
                    );
                    return;
                  }
                  pairing.refresh();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(CaipoSpace.m),
            children: [
              Text(linkStatusLabel(pairing.link), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CaipoSpace.s),
              Text('${AppStrings.bluetooth}: ${pairing.bluetoothState}'),
              if (useSimulatedDevice)
                Padding(
                  padding: const EdgeInsets.only(top: CaipoSpace.s),
                  child: Text(
                    simulatedDeviceStatus(link: pairing.link, scanning: pairing.scanning),
                  ),
                ),
              if (pairing.codecError != null) ...[
                const SizedBox(height: CaipoSpace.m),
                Text(pairing.codecError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (failure != null) ...[
                const SizedBox(height: CaipoSpace.m),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(CaipoSpace.radius),
                  child: Padding(
                    padding: const EdgeInsets.all(CaipoSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(failure.title, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: CaipoSpace.xs),
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
                              child: const Text(AppStrings.openSettings),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: CaipoSpace.m),
              if (pairing.scanning) const LinearProgressIndicator(),
              if (pairing.devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: CaipoSpace.l),
                  child: Text(AppStrings.noDevices),
                ),
              for (final device in pairing.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name.isEmpty ? 'Unnamed device' : device.name),
                  subtitle: Text(
                    [
                      if (device.nearby) 'Nearby' else 'Saved',
                      if (device.rssi != null) '${device.rssi} dBm',
                      if (device.batteryPercent != null) '${AppStrings.battery} ${device.batteryPercent}%',
                      if (pairing.connectedId == device.id) AppStrings.connected,
                    ].join(' · '),
                  ),
                  trailing: pairing.connectedId == device.id
                      ? IconButton(
                          tooltip: AppStrings.forget,
                          onPressed: () => pairing.forget(device.id),
                          icon: const Icon(Icons.link_off),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: pairing.connectedId == device.id
                      ? null
                      : () {
                          caipoHaptic();
                          pairing.connect(device.id, device.name);
                        },
                ),
            ],
          ),
        );
      },
    );
  }
}
