import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging/app_logger.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../conversation/voice_loop.dart';
import '../pairing/pairing_controller.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.pairing, required this.voice});

  final PairingController pairing;
  final VoiceLoopController voice;

  @override
  Widget build(BuildContext context) {
    final lines = AppLogger.lines;
    final errors = [
      for (final line in lines)
        if (line.contains(' error ')) line,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([pairing, voice]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text(AppStrings.diagnostics)),
          body: ListView(
            padding: const EdgeInsets.all(CaipoSpace.m),
            children: [
              Text(AppStrings.liveLink, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CaipoSpace.s),
              Text(_rssi()),
              Text(_speed()),
              const SizedBox(height: CaipoSpace.m),
              Wrap(
                spacing: CaipoSpace.s,
                children: [
                  OutlinedButton(onPressed: () => _share(lines.join('\n'), 'caipo-logs.txt'), child: const Text(AppStrings.exportLogs)),
                  OutlinedButton(
                    onPressed: () {
                      caipoHaptic();
                      _share('CAIPO bug report\n\n${lines.join('\n')}', 'caipo-bug.txt');
                    },
                    child: const Text(AppStrings.bugReport),
                  ),
                ],
              ),
              const SizedBox(height: CaipoSpace.l),
              Text(AppStrings.connectionLogs, style: Theme.of(context).textTheme.titleMedium),
              if (lines.isEmpty) const Text(AppStrings.noLogs) else for (final line in lines.reversed.take(40)) Text(line),
              const SizedBox(height: CaipoSpace.l),
              Text(AppStrings.errorHistory, style: Theme.of(context).textTheme.titleMedium),
              if (errors.isEmpty) const Text(AppStrings.noErrors) else for (final line in errors.reversed) Text(line),
              const SizedBox(height: CaipoSpace.l),
              Text(AppStrings.help, style: Theme.of(context).textTheme.titleMedium),
              for (final item in AppStrings.faq)
                ExpansionTile(
                  title: Text(item.question),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: CaipoSpace.m),
                      child: Align(alignment: Alignment.centerLeft, child: Text(item.answer)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  String _rssi() {
    final rssi = pairing.connectedRssi;
    if (rssi == null) return AppStrings.rssiUnknown;
    return 'RSSI $rssi dBm';
  }

  String _speed() {
    final bytes = voice.lastTransferBytes;
    final millis = voice.lastTransferMillis;
    if (bytes == null || millis == null || millis <= 0) return AppStrings.speedUnknown;
    final perSecond = bytes * 1000 / millis;
    return '$bytes bytes in $millis ms (${perSecond.toStringAsFixed(0)} B/s)';
  }

  Future<void> _share(String text, String name) async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$name');
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: name));
  }
}
