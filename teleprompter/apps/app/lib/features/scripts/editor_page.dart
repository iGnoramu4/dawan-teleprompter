import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_routes.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// 标记草稿（保存时转成 [EditableMarker]）。
class _DraftMarker {
  _DraftMarker({
    required this.kind,
    required this.offset,
    this.label,
  });

  final MarkerKind kind;
  final int offset;
  final String? label;
}

/// 台本编辑器：标题 + 整篇连续正文 + 标记（§4.2 M-01~M-05）。
///
/// 2026-11-11 起台本不再有段落结构，正文始终是一整段连续文本；
/// 标记使用全文绝对字符偏移，与阅读页的连续行号模型一致。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.scriptId});

  final String scriptId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final List<_DraftMarker> _markers = [];

  Timer? _saveTimer;
  bool _loading = true;
  bool _saving = false;
  bool _saveAgain = false;
  bool _dirty = false;
  bool _allowPop = false;
  String? _error;
  int? _savedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final document =
        await ref.read(scriptRepositoryProvider).getDocument(widget.scriptId);
    if (!mounted) return;

    if (document == null) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).editorMissing;
      });
      return;
    }

    _titleController.text = document.title;
    _textController.text = document.rawText;
    for (final marker in document.markers) {
      _markers.add(
        _DraftMarker(
          kind: marker.kind,
          offset: marker.charOffset.clamp(0, document.rawText.length),
          label: marker.label,
        ),
      );
    }

    setState(() => _loading = false);
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    if (_error != null || _loading) return;
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saveTimer?.cancel();
    _saving = true;

    final text = _textController.text;
    final markers = <EditableMarker>[
      for (final marker in _markers)
        EditableMarker(
          charOffset: marker.offset.clamp(0, text.length),
          kind: marker.kind,
          label: marker.label,
        ),
    ];

    try {
      await ref.read(scriptRepositoryProvider).saveDocument(
            scriptId: widget.scriptId,
            title: _titleController.text,
            text: text,
            markers: markers,
          );
      if (mounted) {
        setState(() {
          _dirty = false;
          _savedAt = DateTime.now().millisecondsSinceEpoch;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).editorSaveFailed('$error'),
            ),
          ),
        );
      }
    } finally {
      _saving = false;
      if (_saveAgain) {
        _saveAgain = false;
        _scheduleSave();
      }
    }
  }

  Future<void> _openReader() async {
    await _save();
    final document =
        await ref.read(scriptRepositoryProvider).getDocument(widget.scriptId);
    if (document == null || !mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArgs(document: document),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.editorTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    final theme = Theme.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _save();
        if (!mounted) return;
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.editorTitle),
          actions: [
            IconButton(
              tooltip: l10n.editorAddMarker,
              onPressed: _addMarker,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(right: TpTokens.space1),
              child: Center(
                child: Text(
                  _dirty
                      ? l10n.editorStatusUnsaved
                      : (_savedAt == null
                          ? l10n.editorStatusAutoSave
                          : l10n.editorStatusSaved),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openReader,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.editorPrompt),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            TpTokens.space3,
            TpTokens.space2,
            TpTokens.space3,
            TpTokens.space6,
          ),
          children: [
            TextField(
              controller: _titleController,
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                hintText: l10n.editorTitleHint,
                border: InputBorder.none,
              ),
              onChanged: (_) => _scheduleSave(),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: TpTokens.space2,
                bottom: TpTokens.space2,
              ),
              child: Text(
                l10n.editorStatsChars(
                  _textController.text.replaceAll(RegExp(r'\s'), '').length,
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (_markers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: TpTokens.space2,
                  bottom: TpTokens.space2,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final marker in _markers)
                      InputChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          l10n.editorMarkerAt(
                            _markerKindLabelOf(l10n, marker.kind),
                            marker.offset,
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                        onDeleted: () {
                          setState(() => _markers.remove(marker));
                          _scheduleSave();
                        },
                      ),
                  ],
                ),
              ),
            TextField(
              controller: _textController,
              minLines: 12,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: l10n.editorSectionHint,
                border: InputBorder.none,
              ),
              onChanged: (_) {
                setState(() {});
                _scheduleSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMarker() async {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).editorMarkNeedText),
        ),
      );
      return;
    }

    final result = await showDialog<_DraftMarker>(
      context: context,
      builder: (context) => _MarkerDialog(text: text),
    );
    if (result == null) return;

    setState(() => _markers.add(result));
    _scheduleSave();
  }
}

String _markerKindLabelOf(AppLocalizations l10n, MarkerKind kind) {
  return switch (kind) {
    MarkerKind.emphasis => l10n.markerEmphasis,
    MarkerKind.pause => l10n.markerPause,
    MarkerKind.breath => l10n.markerBreath,
    MarkerKind.action => l10n.markerAction,
    MarkerKind.time => l10n.markerTime,
    MarkerKind.custom => l10n.markerCustom,
  };
}

class _MarkerDialog extends StatefulWidget {
  const _MarkerDialog({required this.text});

  final String text;

  @override
  State<_MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<_MarkerDialog> {
  MarkerKind _kind = MarkerKind.emphasis;
  double _offset = 0;
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offset = _offset.round().clamp(0, widget.text.length - 1);
    final start = offset < 8 ? 0 : offset - 8;
    final end = (offset + 8).clamp(0, widget.text.length);
    final preview =
        '${start > 0 ? '…' : ''}${widget.text.substring(start, offset)}'
        '【${widget.text.substring(offset, offset + 1)}】'
        '${widget.text.substring(offset + 1, end)}'
        '${end < widget.text.length ? '…' : ''}';

    return AlertDialog(
      title: Text(l10n.editorMarkerDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final kind in MarkerKind.values)
                  ChoiceChip(
                    label: Text(_markerKindLabelOf(l10n, kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(preview),
            Slider(
              value: _offset,
              max: (widget.text.length - 1).clamp(1, 10000).toDouble(),
              divisions: (widget.text.length - 1).clamp(1, 1000),
              label: l10n.editorMarkerOffset(offset),
              onChanged: (value) => setState(() => _offset = value),
            ),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: l10n.editorMarkerLabel,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _DraftMarker(
              kind: _kind,
              offset: offset,
              label: _labelController.text.trim().isEmpty
                  ? null
                  : _labelController.text.trim(),
            ),
          ),
          child: Text(l10n.commonAdd),
        ),
      ],
    );
  }
}
