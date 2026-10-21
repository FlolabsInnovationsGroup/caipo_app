import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_mode.dart';
import '../../core/config/app_paths.dart';
import '../../features/conversation/voice_loop.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';

class VoicePanel extends StatefulWidget {
  const VoicePanel({super.key, required this.voice});

  final VoiceLoopController voice;

  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  final AudioPlayer _player = AudioPlayer();
  File? _playable;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _dropPlayable());
  }

  @override
  void dispose() {
    _player.dispose();
    _dropPlayable();
    super.dispose();
  }

  void _dropPlayable() {
    final file = _playable;
    _playable = null;
    unawaited(deletePlaybackCopy(widget.voice.playbackDirectory, file));
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.voice;
    final alert = voice.alert;
    final replyPath = voice.replyWavPath;
    final canPlay = useSimulatedDevice && replyPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(voice.label, style: Theme.of(context).textTheme.titleMedium),
        if (voice.transcript != null) ...[
          const SizedBox(height: CaipoSpace.s),
          Text('${AppStrings.heard}: ${voice.transcript}'),
        ],
        if (voice.replyText != null) ...[
          const SizedBox(height: CaipoSpace.xs),
          Text(voice.replyText!),
        ],
        if (alert != null) ...[
          const SizedBox(height: CaipoSpace.m),
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(CaipoSpace.radius),
            child: Padding(
              padding: const EdgeInsets.all(CaipoSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert),
                  if (voice.retryable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          caipoHaptic();
                          voice.retry();
                        },
                        child: const Text(AppStrings.retry),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        Wrap(
          children: [
            if (voice.phase == VoicePhase.processing || voice.phase == VoicePhase.sending)
              TextButton(
                onPressed: () {
                  caipoHaptic();
                  voice.cancel();
                },
                child: const Text(AppStrings.cancel),
              ),
            if (voice.sessionOpen || voice.phase == VoicePhase.done)
              TextButton(
                onPressed: () {
                  caipoHaptic();
                  voice.endSession();
                },
                child: const Text(AppStrings.endSession),
              ),
            if (canPlay)
              TextButton(
                onPressed: () => _play(replyPath),
                child: const Text(AppStrings.playReply),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _play(String path) async {
    caipoHaptic();
    final bytes = await widget.voice.readStored(path);
    await _player.stop();
    _dropPlayable();
    final playable = await writePlaybackCopy(widget.voice.playbackDirectory, 'reply.wav', bytes);
    _playable = playable;
    await _player.play(DeviceFileSource(playable.path));
  }
}
