import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/app_mode.dart';
import '../../core/config/app_paths.dart';
import '../../core/config/proposed_flags.dart';
import '../../device/protocol/proposed_commands.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../../shared/widgets/voice_panel.dart';
import '../conversation/voice_loop.dart';
import '../live_view/live_view_screen.dart';
import '../pairing/pairing_screen.dart';
import '../pairing/pairing_controller.dart';
import '../shell/led_state.dart';
import '../shell/sim_status.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.pairing,
    required this.voice,
    required this.paths,
  });

  final PairingController pairing;
  final VoiceLoopController voice;
  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    final status = pairing.deviceStatus;
    final led = currentLed(
      link: pairing.link,
      phase: voice.phase,
      failed: pairing.failure != null || pairing.codecError != null || voice.alert != null,
      batteryPercent: pairing.batteryPercent,
      charging: status?.charging ?? false,
      recordingVideo: status?.recordingVideo ?? false,
    );
    final cameraReason = cameraControlReason(commandsEnabled: kProposedCommands, status: status);
    final liveReason = liveViewReason(
      streamEnabled: kProposedStream,
      commandsEnabled: kProposedCommands,
      status: status,
    );
    final connected = pairing.connectedId != null;
    return ListView(
      padding: const EdgeInsets.all(CaipoSpace.m),
      children: [
        Row(
          children: [
            Semantics(
              label: '${AppStrings.state}: ${led.name}',
              child: Container(
                width: CaipoSpace.l,
                height: CaipoSpace.l,
                decoration: BoxDecoration(color: led.color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: CaipoSpace.s),
            Expanded(
              child: Text(linkStatusLabel(pairing.link), style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: CaipoSpace.s),
        Text(
          pairing.batteryPercent == null
              ? '${AppStrings.battery}: —'
              : '${AppStrings.battery}: ${pairing.batteryPercent}%',
        ),
        Text('${AppStrings.state}: ${led.name}'),
        Text(
          status == null ? AppStrings.chargingUnknown : (status.charging ? 'Charging' : 'Not charging'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: CaipoSpace.s),
        Text(_uploadLine(status)),
        if (kProposedCommands && status != null && !status.wifiConnected)
          const Text(AppStrings.hotspotHint),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: kProposedCommands && status != null
                ? () {
                    caipoHaptic();
                    pairing.sendProposed(encodeSyncNow());
                  }
                : null,
            child: const Text(AppStrings.uploadNow),
          ),
        ),
        if (useSimulatedDevice) ...[
          const SizedBox(height: CaipoSpace.s),
          Text(
            simulatedDeviceStatus(
              link: pairing.link,
              scanning: pairing.scanning,
              voiceLabel: connected ? voice.label : null,
            ),
          ),
        ],
        if (pairing.codecError != null) ...[
          const SizedBox(height: CaipoSpace.s),
          Text(pairing.codecError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: CaipoSpace.l),
        Text(AppStrings.talkToAi, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        if (!connected)
          FilledButton(
            onPressed: () => _openPairing(context),
            child: const Text(AppStrings.pairCaipo),
          )
        else ...[
          VoicePanel(voice: voice),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => _openPairing(context), child: const Text(AppStrings.pair)),
          ),
        ],
        const SizedBox(height: CaipoSpace.l),
        Text(AppStrings.lastMedia, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.xs),
        Text(_lastMedia()),
        const SizedBox(height: CaipoSpace.l),
        _CameraAction(
          title: AppStrings.capture,
          icon: Icons.photo_camera_outlined,
          reason: cameraReason,
          onPressed: cameraReason == null ? () => pairing.sendProposed(encodeCaptureImage()) : null,
        ),
        _CameraAction(
          title: AppStrings.recordVideo,
          icon: Icons.videocam_outlined,
          reason: cameraReason,
          onPressed: cameraReason == null ? () => _recordVideo(context) : null,
        ),
        _CameraAction(
          title: AppStrings.liveView,
          icon: Icons.live_tv_outlined,
          reason: liveReason,
          onPressed: liveReason != null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (context) => LiveViewScreen(pairing: pairing)),
                  );
                },
        ),
        const _DisabledAction(title: AppStrings.led, icon: Icons.lightbulb_outline),
        const _DisabledAction(title: AppStrings.gestures, icon: Icons.back_hand_outlined),
        const _DisabledAction(title: AppStrings.firmwareUpdate, icon: Icons.system_update_alt),
        const SizedBox(height: CaipoSpace.m),
        Wrap(
          spacing: CaipoSpace.s,
          runSpacing: CaipoSpace.s,
          children: [
            for (final item in ledLegend)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: CaipoSpace.m,
                    height: CaipoSpace.m,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  const SizedBox(width: CaipoSpace.xs),
                  Text(item.name, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }

  String _uploadLine(DeviceStatus? status) {
    if (!kProposedCommands) return 'Upload status needs the proposed device commands, which are off.';
    if (status == null) return 'Waiting for device status.';
    final count = status.pendingUploads;
    return '$count ${count == 1 ? 'item' : 'items'} waiting to upload';
  }

  Future<void> _recordVideo(BuildContext context) async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(AppStrings.recordVideo),
        children: [
          for (final value in [5, 15, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text('$value s'),
            ),
        ],
      ),
    );
    if (seconds == null) return;
    caipoHaptic();
    await pairing.sendProposed(encodeRecordVideo(seconds));
  }

  void _openPairing(BuildContext context) {
    caipoHaptic();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => PairingScreen(pairing: pairing)),
    );
  }

  String _lastMedia() {
    final files = <File>[
      if (paths.transfers.existsSync()) ...paths.transfers.listSync().whereType<File>(),
      if (paths.replies.existsSync()) ...paths.replies.listSync().whereType<File>(),
    ];
    if (files.isEmpty) return AppStrings.noMedia;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final file = files.first;
    final kb = (file.lengthSync() / 1024).toStringAsFixed(1);
    return '${file.uri.pathSegments.last} · $kb KB';
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.title,
    required this.icon,
    required this.reason,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final String? reason;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final blocked = onPressed == null;
    return Semantics(
      button: true,
      enabled: !blocked,
      label: blocked ? '$title. ${reason ?? AppStrings.needsDeviceSupport}' : title,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: true,
        leading: Icon(icon),
        title: Text(title),
        subtitle: blocked ? Text(reason ?? AppStrings.needsDeviceSupport) : null,
        onTap: () {
          caipoHaptic();
          if (onPressed == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(reason ?? AppStrings.needsDeviceSupport)),
            );
            return;
          }
          onPressed!();
        },
      ),
    );
  }
}

class _DisabledAction extends StatelessWidget {
  const _DisabledAction({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$title. ${AppStrings.needsDeviceSupport}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: const Text(AppStrings.needsDeviceSupport),
        onTap: () {
          caipoHaptic();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.needsDeviceSupport)),
          );
        },
      ),
    );
  }
}
