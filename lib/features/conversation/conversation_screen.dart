import 'package:flutter/material.dart';

import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../../shared/widgets/voice_panel.dart';
import 'history_store.dart';
import 'voice_loop.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.voice});

  final VoiceLoopController voice;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  var _loading = true;
  String? _error;

  ConversationHistoryStore get _history => widget.voice.history;

  @override
  void initState() {
    super.initState();
    widget.voice.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.voice.removeListener(_reload);
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final loaded = await _history.load();
      if (!mounted) return;
      setState(() {
        _entries = loaded;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Conversation could not be opened.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = [
      for (var i = 0; i < _entries.length; i++)
        if (query.isEmpty || '${_entries[i]['text']}'.toLowerCase().contains(query)) _Row(i, _entries[i]),
    ];
    return ListView(
      padding: const EdgeInsets.all(CaipoSpace.m),
      children: [
        Text(AppStrings.talkToAi, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CaipoSpace.s),
        VoicePanel(voice: widget.voice),
        const SizedBox(height: CaipoSpace.m),
        TextField(
          controller: _search,
          decoration: const InputDecoration(labelText: AppStrings.searchConversation),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CaipoSpace.s),
        if (_entries.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _confirmClear,
              child: const Text(AppStrings.deleteAll),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CaipoSpace.l),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CaipoSpace.l),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
        else if (_entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CaipoSpace.l),
            child: Text(AppStrings.noMessages),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CaipoSpace.l),
            child: Text(AppStrings.noSearchHits),
          )
        else
          for (final row in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${row.entry['role']}'),
              subtitle: Text(
                row.entry['status'] == 'not_sent'
                    ? '${row.entry['text']} · ${AppStrings.notSent}'
                    : '${row.entry['text']}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.entry['status'] == 'not_sent' && row.entry['recording'] is String)
                    TextButton(
                      onPressed: () => widget.voice.retryRecording(row.entry['recording'] as String),
                      child: const Text(AppStrings.retry),
                    ),
                  IconButton(
                    tooltip: AppStrings.delete,
                    onPressed: () => _confirmRemove(row.index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _confirmRemove(int index) async {
    final ok = await _confirm(AppStrings.deleteOneTitle);
    if (!ok) return;
    caipoHaptic();
    await _history.removeAt(index);
    await _reload();
  }

  Future<void> _confirmClear() async {
    final ok = await _confirm(AppStrings.deleteAllTitle);
    if (!ok) return;
    caipoHaptic();
    await _history.clear();
    await _reload();
  }

  Future<bool> _confirm(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.delete)),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Row {
  const _Row(this.index, this.entry);

  final int index;
  final Map<String, dynamic> entry;
}
