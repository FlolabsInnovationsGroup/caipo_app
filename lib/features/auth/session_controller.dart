import 'dart:async';

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

  /// How often an open app checks the auto-lock limit.
  static const idleCheckInterval = Duration(seconds: 30);

  final AuthRepository auth;
  final SettingsRepository settings;
  final SharedPreferences preferences;
  final AppLogger logger;
  final DateTime Function() _clock;

  Timer? _idleTimer;

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
    try {
      await auth.signOut();
    } finally {
      signedIn = false;
      locked = false;
      notifyListeners();
    }
  }

  void unlock() {
    locked = false;
    noteActivity();
    notifyListeners();
  }

  Future<void> noteActivity() async {
    await preferences.setString(lastActivityKey, _clock().toIso8601String());
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(idleCheckInterval, (_) => checkIdle());
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Locks a signed-in session after the auto-lock limit with no touches,
  /// including while the app stays open on screen.
  void checkIdle() {
    if (signedIn && !locked && _inactiveTooLong()) {
      locked = true;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkIdle();
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
