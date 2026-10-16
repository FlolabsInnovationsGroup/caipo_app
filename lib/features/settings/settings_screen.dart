import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_mode.dart';
import '../../core/config/app_paths.dart';
import '../../core/config/constants.dart';
import '../../core/errors/app_exception.dart';
import '../../device/wifi/provisioning.dart';
import '../../device/wifi/wifi_networks.dart';
import '../../device/wifi/wifi_sender.dart';
import '../../flobrain/advanced_ai.dart';
import '../../flobrain/profile_repository.dart';
import '../../flobrain/settings_repository.dart';
import '../auth/biometric_gate.dart';
import '../privacy/local_data.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../auth/session_controller.dart';
import '../pairing/pairing_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.pairing,
    required this.settings,
    required this.paths,
    required this.profile,
    required this.wifiNetworks,
    required this.wifiSender,
    required this.privacy,
    required this.biometrics,
    required this.onOpenNotifications,
    required this.onOpenDiagnostics,
  });

  final SessionController session;
  final PairingController pairing;
  final SettingsRepository settings;
  final AppPaths paths;
  final ProfileRepository profile;
  final WifiNetworkStore wifiNetworks;
  final WifiSender wifiSender;
  final PrivacyActions privacy;
  final BiometricGate biometrics;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenDiagnostics;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _email;
  String? _message;
  var _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.profile.get();
      final email = profile['email'];
      if (!mounted) return;
      setState(() {
        _email = email is String ? email : null;
        _profileLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _message = error is AppException ? error.message : 'Profile is not available.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final pairing = widget.pairing;
    final info = pairing.information;
    final minutes = settings.autoLockMinutes();
    return ListView(
      padding: const EdgeInsets.all(CaipoSpace.m),
      children: [
        Text(AppStrings.device, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        Text(_line('Name', _deviceName())),
        Text(_line('Identifier', pairing.connectedId)),
        Text(_line('Firmware', info?.firmware)),
        Text(_line('Serial', info?.serial)),
        Text(_line('Model', info?.model)),
        Text(_line('Manufacturer', info?.manufacturer)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _rename, child: const Text(AppStrings.renameDevice)),
        ),
        const Divider(),
        Text(AppStrings.autoLock, style: Theme.of(context).textTheme.titleMedium),
        Text(AppStrings.autoLockHelp, style: Theme.of(context).textTheme.bodySmall),
        Semantics(
          label: '${AppStrings.autoLock} ${AppStrings.minutes(minutes)}',
          child: Slider(
            min: SettingsRepository.minAutoLockMinutes.toDouble(),
            max: SettingsRepository.maxAutoLockMinutes.toDouble(),
            divisions: SettingsRepository.maxAutoLockMinutes - SettingsRepository.minAutoLockMinutes,
            value: minutes.toDouble(),
            label: AppStrings.minutes(minutes),
            onChanged: (value) async {
              await settings.setAutoLockMinutes(value.round());
              await widget.session.noteActivity();
              if (mounted) setState(() {});
            },
          ),
        ),
        Text(AppStrings.minutes(minutes)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.biometricUnlock),
          subtitle: const Text(AppStrings.biometricHelp),
          value: settings.biometricUnlock(),
          onChanged: (value) async {
            await settings.setBiometricUnlock(value);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.autoConnect),
          subtitle: const Text(AppStrings.autoConnectHelp),
          value: settings.autoConnect(),
          onChanged: (value) async {
            await settings.setAutoConnect(value);
            if (mounted) setState(() {});
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.aiVoice),
          subtitle: Text('${settings.aiVoice()}. ${AppStrings.voiceLanguageLocal}'),
          onTap: () => _pick(AppStrings.aiVoice, SettingsRepository.voices, settings.aiVoice(), settings.setAiVoice),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.aiLanguage),
          subtitle: Text('${settings.aiLanguage()}. ${AppStrings.voiceLanguageLocal}'),
          onTap: () => _pick(
            AppStrings.aiLanguage,
            SettingsRepository.languages,
            settings.aiLanguage(),
            settings.setAiLanguage,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _clearCache, child: const Text(AppStrings.clearCache)),
        ),
        const Divider(),
        Text(AppStrings.wifiNetworks, style: Theme.of(context).textTheme.titleMedium),
        Text(AppStrings.hotspotHint, style: Theme.of(context).textTheme.bodySmall),
        _WifiEditor(store: widget.wifiNetworks, sender: widget.wifiSender, pairing: widget.pairing),
        const Divider(),
        Text(AppStrings.account, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        if (_profileLoading)
          const LinearProgressIndicator()
        else if (_email == null)
          const Text('No profile email yet.')
        else
          Text(_email!),
        if (_message != null) Text(_message!),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _changePassword, child: const Text(AppStrings.changePassword)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.notifications),
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onOpenNotifications,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.diagnostics),
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onOpenDiagnostics,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              caipoHaptic();
              widget.session.signOut();
            },
            child: const Text(AppStrings.signOut),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _deleteAccount, child: const Text(AppStrings.deleteAccount)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _export, child: const Text(AppStrings.exportData)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _deleteLocal, child: const Text(AppStrings.deleteLocalData)),
        ),
        const Divider(),
        Text(AppStrings.advancedAi, style: Theme.of(context).textTheme.titleMedium),
        for (final item in const [
          (AppStrings.sendImage, 'image'),
          (AppStrings.sendVideo, 'video'),
          (AppStrings.systemPrompt, 'prompt'),
          (AppStrings.offlineAi, 'offline'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.$1),
            subtitle: const Text(AdvancedAiClient.unavailable),
            onTap: () => _advanced(item.$2),
          ),
        const Divider(),
        Text(AppStrings.about, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        Text('${AppStrings.appName} $kAppVersionName ($kAppBuildNumber)'),
        Text('${AppStrings.bleContract}: $kBleContractVersion'),
        Text('${AppStrings.currentMode}: ${deviceMode.name} / ${backendMode.name}'),
      ],
    );
  }

  String _deviceName() {
    final id = widget.pairing.connectedId;
    if (id == null) return '—';
    for (final device in widget.pairing.devices) {
      if (device.id == id && device.name.isNotEmpty) return device.name;
    }
    return id;
  }

  String _line(String label, String? value) => '$label: ${value == null || value.isEmpty ? '—' : value}';

  Future<void> _rename() async {
    if (widget.pairing.connectedId == null) {
      setState(() => _message = 'Connect to CAIPO before renaming it.');
      return;
    }
    final controller = TextEditingController(text: _deviceName());
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.renameDevice),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text(AppStrings.save)),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    caipoHaptic();
    await widget.pairing.rename(name);
    if (mounted) setState(() {});
  }

  Future<void> _pick(String title, List<String> options, String current, Future<void> Function(String) save) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option == current ? '$option ·' : option),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await save(chosen);
    if (mounted) setState(() {});
  }

  Future<void> _export() async {
    final text = await widget.privacy.export();
    await SharePlus.instance.share(ShareParams(text: text, subject: 'CAIPO data'));
  }

  Future<void> _deleteLocal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteLocalData),
        content: const Text(AppStrings.deleteLocalHelp),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (ok != true) return;
    caipoHaptic();
    await widget.privacy.deleteAll();
    await widget.session.signOut();
  }

  Future<void> _advanced(String kind) async {
    const client = AdvancedAiClient();
    try {
      switch (kind) {
        case 'image':
          await client.sendImage(const []);
        case 'video':
          await client.sendVideo(const []);
        case 'prompt':
          await client.setSystemPrompt('');
        default:
          await client.replyOffline('');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = AdvancedAiClient.unavailable);
    }
  }

  Future<void> _clearCache() async {
    final count = await widget.paths.clearTransferCache();
    if (!mounted) return;
    setState(() => _message = 'Cleared $count cached transfer${count == 1 ? '' : 's'}.');
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: AppStrings.currentPassword)),
            const SizedBox(height: CaipoSpace.s),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: AppStrings.newPassword)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.save)),
        ],
      ),
    );
    final currentText = current.text;
    final nextText = next.text;
    current.dispose();
    next.dispose();
    if (ok != true) return;
    try {
      await widget.profile.changePassword(currentPassword: currentText, newPassword: nextText);
      if (mounted) setState(() => _message = 'Password updated.');
    } catch (error) {
      if (mounted) setState(() => _message = error is AppException ? error.message : 'Password was not changed.');
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteAccountTitle),
        content: TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: AppStrings.currentPassword),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.delete)),
        ],
      ),
    );
    final passwordText = password.text;
    password.dispose();
    if (confirmed != true || passwordText.isEmpty) return;
    caipoHaptic();
    try {
      await widget.profile.deleteAccount(password: passwordText);
      await widget.session.signOut();
    } catch (error) {
      if (mounted) setState(() => _message = error is AppException ? error.message : 'The account was not deleted.');
    }
  }
}

class _WifiEditor extends StatefulWidget {
  const _WifiEditor({required this.store, required this.sender, required this.pairing});

  final WifiNetworkStore store;
  final WifiSender sender;
  final PairingController pairing;

  @override
  State<_WifiEditor> createState() => _WifiEditorState();
}

class _WifiEditorState extends State<_WifiEditor> {
  List<WifiNetwork> _networks = [];
  String? _note;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final loaded = await widget.store.load();
    if (mounted) setState(() => _networks = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _networks.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_networks[i].phoneHotspot ? '${_networks[i].ssid} · ${AppStrings.phoneHotspot}' : _networks[i].ssid),
            subtitle: Text('${i + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  onPressed: i == 0 ? null : () => _move(i, i - 1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: AppStrings.delete,
                  onPressed: () async {
                    await widget.store.removeAt(i);
                    await _reload();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _add, child: const Text('Add network')),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _send, child: const Text('Send to CAIPO')),
        ),
        if (_note != null) Text(_note!),
      ],
    );
  }

  Future<void> _move(int from, int to) async {
    await widget.store.move(from, to);
    await _reload();
  }

  Future<void> _add() async {
    final ssid = TextEditingController();
    final password = TextEditingController();
    var hotspot = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add network'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ssid, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.phoneHotspot),
                subtitle: const Text(AppStrings.hotspotHint),
                value: hotspot,
                onChanged: (value) => setLocal(() => hotspot = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.save)),
        ],
      ),
    );
    final name = ssid.text.trim();
    final secret = password.text;
    ssid.dispose();
    password.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await widget.store.add(WifiNetwork(ssid: name, password: secret, phoneHotspot: hotspot));
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _note = '$error');
    }
  }

  Future<void> _send() async {
    final id = widget.pairing.connectedId;
    final result = await const WifiProvisioner().send(
      networks: _networks,
      deviceToken: '',
      bonded: widget.pairing.bonded,
      writePayload: (payload) async {
        if (id == null) throw StateError('Connect to CAIPO first.');
        await widget.sender.send(id, payload);
      },
    );
    if (mounted) setState(() => _note = result.detail);
  }
}
