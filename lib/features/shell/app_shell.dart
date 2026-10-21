import 'package:flutter/material.dart';

import '../../core/config/app_paths.dart';
import '../../device/wifi/wifi_networks.dart';
import '../../device/wifi/wifi_sender.dart';
import '../../device/device_state.dart';
import '../../flobrain/profile_repository.dart';
import '../../flobrain/settings_repository.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../auth/session_controller.dart';
import '../../device/protocol/transfer_archive.dart';
import '../conversation/conversation_screen.dart';
import '../conversation/photo_question.dart';
import '../conversation/voice_loop.dart';
import '../dashboard/dashboard_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../media_library/media_library_screen.dart';
import '../notifications/notification_center.dart';
import '../notifications/notifications_screen.dart';
import '../auth/biometric_gate.dart';
import '../pairing/pairing_controller.dart';
import '../privacy/local_data.dart';
import '../settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.pairing,
    required this.settings,
    required this.voice,
    required this.notices,
    required this.paths,
    required this.profile,
    required this.wifiNetworks,
    required this.wifiSender,
    required this.privacy,
    required this.biometrics,
    this.photo,
    this.archive,
  });

  final SessionController session;
  final PairingController pairing;
  final SettingsRepository settings;
  final VoiceLoopController voice;
  final NotificationCenter notices;
  final AppPaths paths;
  final ProfileRepository profile;
  final WifiNetworkStore wifiNetworks;
  final WifiSender wifiSender;
  final PrivacyActions privacy;
  final BiometricGate biometrics;
  final PhotoQuestionController? photo;
  final TransferArchive? archive;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;
  CaipoLinkState? _seenLink;
  VoicePhase? _seenPhase;
  var _lowBatterySent = false;

  @override
  void initState() {
    super.initState();
    widget.pairing.addListener(_onDevice);
    widget.voice.addListener(_onDevice);
    widget.notices.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.pairing.removeListener(_onDevice);
    widget.voice.removeListener(_onDevice);
    widget.notices.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onDevice() {
    final link = widget.pairing.link;
    if (_seenLink == CaipoLinkState.connected &&
        (link == CaipoLinkState.reconnecting ||
            link == CaipoLinkState.disconnected ||
            link == CaipoLinkState.pairingFailed)) {
      widget.notices.connectionLost();
    }
    _seenLink = link;

    final battery = widget.pairing.batteryPercent;
    if (battery != null && battery <= 20) {
      if (!_lowBatterySent) {
        _lowBatterySent = true;
        widget.notices.lowBattery(battery);
      }
    } else {
      _lowBatterySent = false;
    }

    final phase = widget.voice.phase;
    if (_seenPhase != null && _seenPhase != VoicePhase.done && phase == VoicePhase.done) {
      widget.notices.transferDone();
    }
    _seenPhase = phase;
    _rebuild();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(pairing: widget.pairing, voice: widget.voice, paths: widget.paths),
      ConversationScreen(voice: widget.voice, photo: widget.photo, archive: widget.archive),
      MediaLibraryScreen(paths: widget.paths, voice: widget.voice),
      SettingsScreen(
        session: widget.session,
        pairing: widget.pairing,
        settings: widget.settings,
        paths: widget.paths,
        profile: widget.profile,
        wifiNetworks: widget.wifiNetworks,
        wifiSender: widget.wifiSender,
        privacy: widget.privacy,
        biometrics: widget.biometrics,
        onOpenNotifications: () => _open(NotificationsScreen(notices: widget.notices)),
        onOpenDiagnostics: () => _open(DiagnosticsScreen(pairing: widget.pairing, voice: widget.voice)),
      ),
    ];
    final titles = [
      AppStrings.dashboard,
      AppStrings.conversation,
      AppStrings.library,
      AppStrings.settings,
    ];
    final banner = widget.notices.banner;
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: AppStrings.notifications,
            onPressed: () => _open(NotificationsScreen(notices: widget.notices)),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: AppStrings.diagnostics,
            onPressed: () => _open(DiagnosticsScreen(pairing: widget.pairing, voice: widget.voice)),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (banner != null)
            MaterialBanner(
              content: Text('${banner.title}. ${banner.body}'),
              actions: [
                TextButton(onPressed: widget.notices.dismissBanner, child: const Text(AppStrings.dismiss)),
              ],
            ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          caipoHaptic();
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: AppStrings.dashboard),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: AppStrings.conversation),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), label: AppStrings.library),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: AppStrings.settings),
        ],
      ),
    );
  }

  void _open(Widget route) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => route));
  }
}
