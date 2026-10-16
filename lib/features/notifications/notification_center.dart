import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../shared/copy/app_strings.dart';

class AppNotice {
  AppNotice({required this.title, required this.body, required this.at});

  final String title;
  final String body;
  final DateTime at;
}

class NotificationCenter extends ChangeNotifier {
  NotificationCenter(this.preferences, {AppLogger? logger}) : logger = logger ?? const AppLogger();

  static const batteryKey = 'caipo.notify.battery';
  static const linkKey = 'caipo.notify.link';
  static const transferKey = 'caipo.notify.transfer';

  final SharedPreferences preferences;
  final AppLogger logger;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final List<AppNotice> items = [];

  AppNotice? banner;
  var _ready = false;
  var _id = 0;

  bool get lowBatteryEnabled => preferences.getBool(batteryKey) ?? true;

  bool get linkLostEnabled => preferences.getBool(linkKey) ?? true;

  bool get transferDoneEnabled => preferences.getBool(transferKey) ?? true;

  Future<void> setLowBattery(bool value) => _set(batteryKey, value);

  Future<void> setLinkLost(bool value) => _set(linkKey, value);

  Future<void> setTransferDone(bool value) => _set(transferKey, value);

  Future<void> lowBattery(int percent) {
    return _post(AppStrings.lowBatteryTitle, AppStrings.lowBatteryBody(percent), enabled: lowBatteryEnabled);
  }

  Future<void> connectionLost() {
    return _post(AppStrings.linkLostTitle, AppStrings.linkLostBody, enabled: linkLostEnabled);
  }

  Future<void> transferDone() {
    return _post(AppStrings.transferDoneTitle, AppStrings.transferDoneBody, enabled: transferDoneEnabled);
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await Permission.notification.request();
  }

  void dismissBanner() {
    banner = null;
    notifyListeners();
  }

  Future<void> _set(String key, bool value) async {
    await preferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> _post(String title, String body, {required bool enabled}) async {
    if (!enabled) return;
    final notice = AppNotice(title: title, body: body, at: DateTime.now());
    items.insert(0, notice);
    if (items.length > 50) items.removeLast();
    banner = notice;
    notifyListeners();
    await _showLocal(title, body);
  }

  Future<void> _showLocal(String title, String body) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      if (!_ready) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted && !granted.isLimited) return;
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
        _ready = true;
      }
      _id += 1;
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'caipo',
            'CAIPO',
            channelDescription: 'Battery, connection, and transfer alerts',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error, stack) {
      logger.warn('Local notification was not shown: $error');
      logger.debug('$stack');
    }
  }
}
