import 'package:flutter/material.dart';

import '../../shared/copy/app_strings.dart';
import '../../shared/theme/caipo_tokens.dart';
import 'notification_center.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.notices});

  final NotificationCenter notices;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notices,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text(AppStrings.notifications)),
          body: ListView(
            padding: const EdgeInsets.all(CaipoSpace.m),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.lowBatteryPref),
                value: notices.lowBatteryEnabled,
                onChanged: notices.setLowBattery,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.linkLostPref),
                value: notices.linkLostEnabled,
                onChanged: notices.setLinkLost,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.transferDonePref),
                value: notices.transferDoneEnabled,
                onChanged: notices.setTransferDone,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: notices.requestPermission,
                  child: const Text(AppStrings.allowNotifications),
                ),
              ),
              const SizedBox(height: CaipoSpace.m),
              Text(AppStrings.notificationList, style: Theme.of(context).textTheme.titleMedium),
              if (notices.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: CaipoSpace.l),
                  child: Text(AppStrings.noNotifications),
                )
              else
                for (final item in notices.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(item.body),
                  ),
            ],
          ),
        );
      },
    );
  }
}
