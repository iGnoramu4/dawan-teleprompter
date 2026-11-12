import 'package:core_models/core_models.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_routes.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// 导入预览：粘贴 / txt / md 统一走这里，先清洗再保存（§4.1 S-09）。
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({
    super.key,
    required this.rawText,
    this.sourceLabel,
    this.stripMarkdown = false,
  });

  final String rawText;

  /// 来源标签；为空时使用通用“导入”文案。
  final String? sourceLabel;
  final bool stripMarkdown;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late CleanOptions _options;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _options = CleanOptions(
      stripMarkdown: widget.stripMarkdown,
      // 粘贴内容常带硬换行，默认合并；文件导入同理。
      mergeHardLineBreaks: true,
    );
    final cleaned = cleanImportedText(widget.rawText, _options);
    _titleController = TextEditingController(
      text: suggestTitle(cleaned, fallback: ''),
    );
    _textController = TextEditingController(text: widget.rawText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String get _cleaned => cleanImportedText(_textController.text, _options);

  void _updateOptions(AppLocalizations l10n, CleanOptions options) {
    setState(() {
      _options = options;
      if (_titleController.text.trim().isEmpty ||
          _titleController.text == l10n.editorUnnamedScript) {
        _titleController.text = suggestTitle(_cleaned);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cleaned = _cleaned;
    final theme = Theme.of(context);
    final source = widget.sourceLabel ?? l10n.importDefaultSource;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importPreviewTitle(source)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          TpTokens.space3,
          TpTokens.space2,
          TpTokens.space3,
          140,
        ),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.importTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: TpTokens.space3),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(TpTokens.space2),
              child: Column(
                children: [
                  SwitchListTile(
                    dense: true,
                    value: _options.mergeHardLineBreaks,
                    title: Text(l10n.importMergeHardBreaks),
                    subtitle: Text(l10n.importMergeHardBreaksHint),
                    onChanged: (value) => _updateOptions(
                      l10n,
                      _options.copyWith(mergeHardLineBreaks: value),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: _options.stripHeadersFooters,
                    title: Text(l10n.importStripHeaders),
                    onChanged: (value) => _updateOptions(
                      l10n,
                      _options.copyWith(stripHeadersFooters: value),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: _options.normalizeWidth,
                    title: Text(l10n.importNormalizeWidth),
                    onChanged: (value) => _updateOptions(
                      l10n,
                      _options.copyWith(normalizeWidth: value),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: _options.stripMarkdown,
                    title: Text(l10n.importStripMarkdown),
                    onChanged: (value) => _updateOptions(
                      l10n,
                      _options.copyWith(stripMarkdown: value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TpTokens.space3),
          Text(
            l10n.importCleanedStats(
              cleaned.replaceAll(RegExp(r'\s'), '').length,
            ),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: TpTokens.space1),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(TpTokens.space3),
              child: Text(
                cleaned.isEmpty ? l10n.importEmptyPreview : cleaned,
                maxLines: 14,
                overflow: TextOverflow.fade,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: TpTokens.space3),
          Text(l10n.importRawEditable, style: theme.textTheme.labelLarge),
          const SizedBox(height: TpTokens.space2),
          TextField(
            controller: _textController,
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TpTokens.space3),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save(openReader: false),
                  child: Text(l10n.importSaveAndEdit),
                ),
              ),
              const SizedBox(width: TpTokens.space2),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(openReader: true),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.importSaveAndPrompt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save({required bool openReader}) async {
    final l10n = AppLocalizations.of(context);
    final cleaned = _cleaned;
    if (cleaned.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importNoContent)),
      );
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(scriptRepositoryProvider);
    final document = await repository.createScript(
      title: _titleController.text.trim().isEmpty
          ? l10n.editorUnnamedScript
          : _titleController.text,
      text: cleaned,
    );
    if (!mounted) return;

    if (openReader) {
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.reader,
        arguments: ReaderArgs(document: document),
      );
    } else {
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.editor,
        arguments: EditorArgs(document.id),
      );
    }
  }
}
