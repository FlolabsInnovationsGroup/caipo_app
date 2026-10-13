import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../flobrain/auth_repository.dart';
import '../../flobrain/settings_repository.dart';

class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({
    required this.auth,
    required this.settings,
    required this.preferences,
    required this.logger,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const lastActivityKey = 'caipo.last_activity';

  final AuthRepository auth;
  final SettingsRepository settings;
  final SharedPreferences preferences;
  final AppLogger logger;
  final DateTime Function() _clock;

  bool ready = false;
  bool signedIn = false;
  bool locked = false;
  String? error;

  Future<void> bootstrap() async {
    final tokens = await auth.restore();
    signedIn = tokens != null;
    locked = signedIn && _inactiveTooLong();
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    error = null;
    await auth.signIn(email: email, password: password);
    signedIn = true;
    locked = false;
    await noteActivity();
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    error = null;
    await auth.register(email: email, password: password);
    signedIn = true;
    locked = false;
    await noteActivity();
    notifyListeners();
  }

  Future<void> signOut() async {
    await auth.signOut();
    signedIn = false;
    locked = false;
    notifyListeners();
  }

  Future<void> noteActivity() async {
    await preferences.setString(lastActivityKey, _clock().toIso8601String());
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (signedIn && _inactiveTooLong()) {
        locked = true;
        notifyListeners();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      noteActivity();
    }
  }

  bool _inactiveTooLong() {
    final raw = preferences.getString(lastActivityKey);
    if (raw == null) return false;
    final last = DateTime.tryParse(raw);
    if (last == null) return false;
    final limit = Duration(minutes: settings.autoLockMinutes());
    return _clock().difference(last) >= limit;
  }
}
