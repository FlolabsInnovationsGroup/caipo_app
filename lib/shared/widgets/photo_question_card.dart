import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/constants.dart';
import '../../device/protocol/transfer_archive.dart';
import '../../features/conversation/photo_question.dart';
import '../copy/app_strings.dart';
import '../feedback/haptics.dart';
import '../theme/caipo_tokens.dart';

/// Pick a photo, type a question, read FloBrain's answer.
class PhotoQuestionCard extends StatefulWidget {
  const PhotoQuestionCard({super.key, required this.photo, required this.archive});

  final PhotoQuestionController photo;
  final TransferArchive archive;

  @override
  State<PhotoQuestionCard> createState() => _PhotoQuestionCardState();
}

class _PhotoQuestionCardState extends State<PhotoQuestionCard> {
  final _question = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _pickError;

  PhotoQuestionController get _photo => widget.photo;

  @override
  void initState() {
    super.initState();
    _photo.addListener(_changed);
  }

  @override
  void dispose() {
    _photo.removeListener(_changed);
    _question.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sending = _photo.phase == PhotoQuestionPhase.sending;
    final alert = _pickError ?? _photo.alert ?? (_photo.blocked ? PhotoQuestionController.blockedMessage : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.askAboutPhoto, style: theme.textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.xs),
        const Text(AppStrings.askAboutPhotoHelp),
        const SizedBox(height: CaipoSpace.s),
        Wrap(
          spacing: CaipoSpace.s,
          children: [
            OutlinedButton.icon(
              onPressed: sending ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text(AppStrings.takePhoto),
            ),
            OutlinedButton.icon(
              onPressed: sending ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text(AppStrings.choosePhoto),
            ),
            OutlinedButton.icon(
              onPressed: sending ? null : _fromCaipo,
              icon: const Icon(Icons.memory_outlined),
              label: const Text(AppStrings.lastCaipoPhoto),
            ),
          ],
        ),
        if (_bytes != null) ...[
          const SizedBox(height: CaipoSpace.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(CaipoSpace.radius),
            child: Image.memory(
              _bytes!,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Text(AppStrings.photoUnreadable),
            ),
          ),
        ],
        const SizedBox(height: CaipoSpace.s),
        TextField(
          controller: _question,
          enabled: !sending,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _ask(),
          decoration: const InputDecoration(labelText: AppStrings.photoQuestion),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: sending || _bytes == null || _photo.blocked ? null : _ask,
              child: Text(sending ? AppStrings.asking : AppStrings.ask),
            ),
            if (sending)
              TextButton(
                onPressed: () {
                  caipoHaptic();
                  _photo.cancel();
                },
                child: const Text(AppStrings.cancel),
              ),
          ],
        ),
        if (sending) const LinearProgressIndicator(),
        if (_photo.reply != null) ...[
          const SizedBox(height: CaipoSpace.xs),
          Text(_photo.reply!),
        ],
        if (alert != null) ...[
          const SizedBox(height: CaipoSpace.s),
          Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(CaipoSpace.radius),
            child: Padding(
              padding: const EdgeInsets.all(CaipoSpace.m),
              child: Text(alert),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(ImageSource source) async {
    caipoHaptic();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: kPhotoMaxWidth,
        imageQuality: kPhotoJpegQuality,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _bytes = bytes;
        _pickError = null;
      });
    } catch (_) {
      setState(() => _pickError = AppStrings.photoPickFailed);
    }
  }

  Future<void> _fromCaipo() async {
    caipoHaptic();
    final file = widget.archive.latest(kContentTypeImage);
    if (file == null) {
      setState(() => _pickError = AppStrings.noCaipoPhoto);
      return;
    }
    try {
      final bytes = await widget.archive.read(file);
      setState(() {
        _bytes = bytes;
        _pickError = PhotoQuestionController.mimeOf(bytes) == null ? AppStrings.photoUnreadable : null;
      });
    } catch (_) {
      setState(() => _pickError = AppStrings.photoUnreadable);
    }
  }

  Future<void> _ask() async {
    final bytes = _bytes;
    if (bytes == null) return;
    caipoHaptic();
    setState(() => _pickError = null);
    await _photo.ask(photo: bytes, question: _question.text);
  }
}
