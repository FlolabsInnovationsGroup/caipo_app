import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/security/at_rest.dart';
import '../../core/config/app_paths.dart';
import '../../core/config/constants.dart';
import '../../device/audio/opus_codec.dart';
import '../../flobrain/proposed_clients.dart';
import '../../device/audio/wav_pcm.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../conversation/voice_loop.dart';
import 'clip_player.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key, required this.paths, required this.voice});

  final AppPaths paths;
  final VoiceLoopController voice;

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  @override
  void initState() {
    super.initState();
    widget.voice.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.voice.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final audio = _audioFiles();
    final photos = _typed(kContentTypeImage);
    return ListView(
      padding: const EdgeInsets.all(CaipoSpace.m),
      children: [
        Text(AppStrings.library, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        if (audio.isEmpty)
          const Text(AppStrings.audioEmpty)
        else
          for (final file in audio) _AudioTile(file: file, voice: widget.voice, onChanged: _refresh),
        const SizedBox(height: CaipoSpace.l),
        Text('Photos', style: Theme.of(context).textTheme.titleMedium),
        Text(FloBrainMediaClient.unavailable, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: CaipoSpace.s),
        if (photos.isEmpty)
          const Text(AppStrings.photosEmpty)
        else
          for (final file in photos) _FileTile(file: file, onChanged: _refresh),
        const SizedBox(height: CaipoSpace.l),
        Text('Video', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        const Text(AppStrings.videoEmpty),
      ],
    );
  }

  List<File> _audioFiles() {
    final files = <File>[
      ..._typed(kContentTypeAudio),
      if (widget.paths.replies.existsSync())
        ...widget.paths.replies.listSync().whereType<File>().where((file) => file.path.endsWith('.wav')),
    ];
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  List<File> _typed(int type) {
    if (!widget.paths.transfers.existsSync()) return const [];
    return widget.paths.transfers
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('_type$type'))
        .toList();
  }
}

class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.file, required this.voice, required this.onChanged});

  final File file;
  final VoiceLoopController voice;
  final VoidCallback onChanged;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  File? _wav;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final wav = await _playableWav(widget.file, widget.voice.archive.cipher);
      if (!mounted) return;
      setState(() => _wav = wav);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.voice.replyWavPath == widget.file.path ? widget.voice.replyText : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.file.uri.pathSegments.last),
          subtitle: Text(_error ?? '${widget.file.lengthSync()} bytes'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppStrings.share,
                onPressed: _wav == null ? null : () => _share(_wav!),
                icon: const Icon(Icons.share_outlined),
              ),
              IconButton(
                tooltip: AppStrings.delete,
                onPressed: () => _delete(widget.file),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        if (_wav != null) ClipPlayer(file: _wav!, caption: caption),
      ],
    );
  }

  Future<void> _delete(File file) async {
    caipoHaptic();
    if (file.existsSync()) await file.delete();
    final sidecar = File('${file.path}.wav');
    if (sidecar.existsSync() && sidecar.path != file.path) await sidecar.delete();
    widget.onChanged();
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onChanged});

  final File file;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(file.uri.pathSegments.last),
      subtitle: Text('${file.lengthSync()} bytes. ${AppStrings.imagePreview}'),
      trailing: IconButton(
        tooltip: AppStrings.delete,
        onPressed: () async {
          caipoHaptic();
          if (file.existsSync()) await file.delete();
          onChanged();
        },
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

Future<File> _playableWav(File source, AtRestCipher? cipher) async {
  final stored = Uint8List.fromList(await source.readAsBytes());
  final bytes = cipher == null ? stored : await cipher.open(stored);
  if (source.path.toLowerCase().endsWith('.wav') && (cipher == null || !cipher.isSealed(stored))) {
    return source;
  }
  if (source.path.toLowerCase().endsWith('.wav')) {
    final out = File('${source.path}.play.wav');
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }
  final pcm = OpusCodec.shared.decodeContainer(bytes);
  final out = File('${source.path}.wav');
  await out.writeAsBytes(writePcmWav(pcm), flush: true);
  return out;
}

Future<void> _share(File file) {
  return SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}
