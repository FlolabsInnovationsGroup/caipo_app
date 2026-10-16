import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../device/audio/wav_pcm.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';

const playbackSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

class ClipPlayer extends StatefulWidget {
  const ClipPlayer({super.key, required this.file, this.caption});

  final File file;
  final String? caption;

  @override
  State<ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<ClipPlayer> {
  final AudioPlayer _player = AudioPlayer();
  List<double> _peaks = const [];
  var _speed = 1.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final wav = parseWav(Uint8List.fromList(await widget.file.readAsBytes()));
      final peaks = _peaksOf(wav.samples);
      if (!mounted) return;
      setState(() {
        _peaks = peaks;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          width: double.infinity,
          child: CustomPaint(
            painter: _WavePainter(peaks: _peaks, color: Theme.of(context).colorScheme.primary),
          ),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: CaipoSpace.s),
        Text(AppStrings.playbackSpeed, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: CaipoSpace.xs,
          children: [
            for (final speed in playbackSpeeds)
              ChoiceChip(
                label: Text('${speed}x'),
                selected: _speed == speed,
                onSelected: (_) => _setSpeed(speed),
              ),
          ],
        ),
        TextButton(
          onPressed: _error == null ? _play : null,
          child: const Text(AppStrings.playReply),
        ),
        if (widget.caption != null) ...[
          Text('${AppStrings.replyText}: ${widget.caption}'),
          Text(AppStrings.transcriptSyncNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _player.setPlaybackRate(speed);
  }

  Future<void> _play() async {
    caipoHaptic();
    await _player.setPlaybackRate(_speed);
    await _player.stop();
    await _player.play(DeviceFileSource(widget.file.path));
  }
}

List<double> _peaksOf(Int16List samples) {
  if (samples.isEmpty) return const [];
  const buckets = 48;
  final size = math.max(1, samples.length ~/ buckets);
  final peaks = <double>[];
  for (var start = 0; start < samples.length && peaks.length < buckets; start += size) {
    var peak = 0;
    final end = math.min(samples.length, start + size);
    for (var i = start; i < end; i++) {
      final value = samples[i].abs();
      if (value > peak) peak = value;
    }
    peaks.add(peak / 32768);
  }
  return peaks;
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.peaks, required this.color});

  final List<double> peaks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (peaks.isEmpty) {
      canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, 1.0), paint);
      return;
    }
    final slot = size.width / peaks.length;
    for (var i = 0; i < peaks.length; i++) {
      final height = math.max(2.0, peaks[i] * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + 1, (size.height - height) / 2, math.max(1.0, slot - 2), height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.peaks != peaks || oldDelegate.color != color;
}
