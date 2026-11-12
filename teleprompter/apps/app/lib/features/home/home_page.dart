import 'dart:async';
import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_routes.dart';
import '../../data/app_log.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/document_import.dart';
import '../../utils/text_encoding.dart';

enum _ScriptAction {
  edit,
  rename,
  favorite,
  unfavorite,
  archive,
  unarchive,
  duplicate,
  export,
  delete,
  restore,
  purge,
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summaries = ref.watch(scriptSummariesProvider);
    final view = ref.watch(scriptViewProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.homeSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    ref.read(scriptQueryProvider.notifier).state = value,
              )
            : Text(l10n.appScriptsTitle),
        actions: [
          IconButton(
            tooltip: _searching ? l10n.homeSearchClose : l10n.homeSearch,
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchController.clear();
                ref.read(scriptQueryProvider.notifier).state = '';
              }
            },
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          PopupMenuButton<ScriptSort>(
            tooltip: l10n.homeSortTooltip,
            icon: const Icon(Icons.sort),
            initialValue: ref.read(scriptSortProvider),
            onSelected: (value) =>
                ref.read(scriptSortProvider.notifier).state = value,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ScriptSort.updatedDesc,
                child: Text(l10n.homeSortUpdated),
              ),
              PopupMenuItem(
                value: ScriptSort.createdDesc,
                child: Text(l10n.homeSortCreated),
              ),
              PopupMenuItem(
                value: ScriptSort.titleAsc,
                child: Text(l10n.homeSortTitle),
              ),
              PopupMenuItem(
                value: ScriptSort.charCountDesc,
                child: Text(l10n.homeSortChars),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.homeMenuExportAll,
            onPressed: _exportAll,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            tooltip: l10n.homeSettingsTooltip,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildViewChips(l10n, view),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
          Expanded(
            child: summaries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  _buildError(l10n.homeErrorLoad('$error')),
              data: (items) => _buildList(items, view),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: Text(l10n.homeNew),
      ),
    );
  }

  Widget _buildViewChips(AppLocalizations l10n, ScriptView current) {
    final views = [
      (ScriptView.active, l10n.homeViewAll),
      (ScriptView.favorite, l10n.homeViewFavorite),
      (ScriptView.archived, l10n.homeViewArchived),
      (ScriptView.trash, l10n.homeViewTrash),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: TpTokens.space3),
        scrollDirection: Axis.horizontal,
        itemCount: views.length,
        separatorBuilder: (_, __) => const SizedBox(width: TpTokens.space2),
        itemBuilder: (context, index) {
          final (view, label) = views[index];
          return Center(
            child: FilterChip(
              label: Text(label),
              selected: current == view,
              onSelected: (_) =>
                  ref.read(scriptViewProvider.notifier).state = view,
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: TpTokens.space3),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: TpTokens.space4),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(scriptSummariesProvider),
              child: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<ScriptSummary> items, ScriptView view) {
    if (items.isEmpty) {
      return _buildEmpty(view);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        TpTokens.space3,
        TpTokens.space2,
        TpTokens.space3,
        96,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: TpTokens.space1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ScriptTile(
          item: item,
          inTrash: view == ScriptView.trash,
          onOpen: view == ScriptView.trash ? null : () => _openReader(item),
          onAction: (action) => _handleAction(item, action),
        );
      },
    );
  }

  Widget _buildEmpty(ScriptView view) {
    final l10n = AppLocalizations.of(context);
    final (icon, title, hint) = switch (view) {
      ScriptView.active => (
          Icons.article_outlined,
          l10n.homeEmptyActiveTitle,
          l10n.homeEmptyActiveHint,
        ),
      ScriptView.favorite => (
          Icons.star_outline,
          l10n.homeEmptyFavoriteTitle,
          l10n.homeEmptyFavoriteHint,
        ),
      ScriptView.archived => (
          Icons.archive_outlined,
          l10n.homeEmptyArchivedTitle,
          l10n.homeEmptyArchivedHint,
        ),
      ScriptView.trash => (
          Icons.delete_outline,
          l10n.homeEmptyTrashTitle,
          l10n.homeEmptyTrashHint,
        ),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: TpTokens.space3),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: TpTokens.space1),
          Text(hint, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _handleAction(ScriptSummary item, _ScriptAction action) async {
    final repository = ref.read(scriptRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _ScriptAction.edit:
        await Navigator.of(context).pushNamed(
          AppRoutes.editor,
          arguments: EditorArgs(item.id),
        );
      case _ScriptAction.rename:
        await _rename(item);
      case _ScriptAction.favorite:
        await repository.setFavorite(item.id, true);
      case _ScriptAction.unfavorite:
        await repository.setFavorite(item.id, false);
      case _ScriptAction.archive:
        await repository.setArchived(item.id, true);
      case _ScriptAction.unarchive:
        await repository.setArchived(item.id, false);
      case _ScriptAction.duplicate:
        await repository.duplicate(item.id);
        _toast(l10n.homeCopied(item.title));
      case _ScriptAction.export:
        await _exportTps(item);
      case _ScriptAction.delete:
        await repository.softDelete(item.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.homeMovedToTrash(item.title)),
            action: SnackBarAction(
              label: l10n.commonUndo,
              onPressed: () => repository.restore(item.id),
            ),
          ),
        );
      case _ScriptAction.restore:
        await repository.restore(item.id);
        _toast(l10n.homeRestored(item.title));
      case _ScriptAction.purge:
        final confirmed = await _confirmPurge(item);
        if (!confirmed) return;
        await repository.deleteForever(item.id);
        _toast(l10n.homePurged(item.title));
    }
  }

  Future<void> _rename(ScriptSummary item) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: item.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homeRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.homeTitleLabel),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(scriptRepositoryProvider).rename(item.id, name);
  }

  Future<bool> _confirmPurge(ScriptSummary item) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homePurgeTitle),
        content: Text(l10n.homePurgeConfirm(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openReader(ScriptSummary item) async {
    final repository = ref.read(scriptRepositoryProvider);
    final document = await repository.getDocument(item.id);
    if (document == null || !mounted) return;
    final anchor = await repository.lastAnchor(item.id) ?? 0;
    final anchorModel = await repository.lastAnchorModel(item.id);
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArgs(
        document: document,
        initialAnchor: anchor,
        initialAnchorModel: anchorModel,
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.homeCreateBlank),
              subtitle: Text(l10n.homeCreateBlankHint),
              onTap: () => Navigator.of(context).pop('blank'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_outlined),
              title: Text(l10n.homeCreatePaste),
              subtitle: Text(l10n.homeCreatePasteHint),
              onTap: () => Navigator.of(context).pop('paste'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.homeCreateFile),
              subtitle: Text(l10n.homeCreateFileHint),
              onTap: () => Navigator.of(context).pop('file'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'blank':
        await _createBlank();
      case 'paste':
        await _importFromClipboard();
      case 'file':
        await _importFromFile();
    }
  }

  Future<void> _createBlank() async {
    final l10n = AppLocalizations.of(context);
    final document = await ref
        .read(scriptRepositoryProvider)
        .createScript(title: l10n.editorUnnamedScript, text: '');
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.editor,
      arguments: EditorArgs(document.id),
    );
  }

  Future<void> _importFromClipboard() async {
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _toast(l10n.homeClipboardEmpty);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.importPreview,
      arguments: ImportArgs(
        rawText: text,
        sourceLabel: l10n.homeClipboardSource,
      ),
    );
  }

  Future<void> _importFromFile() async {
    // 已知扩展名在 SAF 中会被 MIME 过滤禁用（例如 .tps），因此选择任意文件后在代码内校验。
    final file = await FilePicker.pickFile();
    if (file == null) return;

    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final extension = (file.extension ?? '').toLowerCase();
    if (extension == 'docx') {
      await _importDocument(() => extractDocxText(bytes), file.name);
      return;
    }
    if (extension == 'pdf') {
      await _importDocument(() => extractPdfText(bytes), file.name);
      return;
    }
    final text = decodeTextBytes(bytes);
    if (extension == ScriptBundleFormat.extension) {
      await _importTps(text);
      return;
    }
    if (extension != 'txt' && extension != 'md' && extension != 'markdown') {
      _toast(l10n.homeImportUnsupported);
      return;
    }
    final isMarkdown = extension == 'md' || extension == 'markdown';
    await Navigator.of(context).pushNamed(
      AppRoutes.importPreview,
      arguments: ImportArgs(
        rawText: text,
        sourceLabel: file.name,
        stripMarkdown: isMarkdown,
      ),
    );
  }

  /// 导入 Word/PDF：提取文字后进入同一个导入预览页。
  Future<void> _importDocument(
    FutureOr<String> Function() extract,
    String sourceLabel,
  ) async {
    String text;
    try {
      text = await extract();
    } on FormatException {
      if (mounted) _toast(AppLocalizations.of(context).homeImportParseFailed);
      return;
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context).homeImportParseFailed);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.importPreview,
      arguments: ImportArgs(rawText: text, sourceLabel: sourceLabel),
    );
  }

  Future<void> _importTps(String text) async {
    final l10n = AppLocalizations.of(context);
    ScriptBundle bundle;
    try {
      bundle = ScriptBundle.decode(text);
    } on FormatException {
      _toast(l10n.homeImportTpsInvalid);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homeImportTpsTitle),
        content: Text(l10n.homeImportTpsConfirm(bundle.scriptCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final imported =
        await ref.read(scriptRepositoryProvider).importBundle(bundle);
    AppLog.instance.event('home', 'import_tps', {'scripts': imported});
    _toast(l10n.homeImportTpsDone(imported));
  }

  Future<void> _exportTps(ScriptSummary item) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(scriptRepositoryProvider);
    final document = await repository.getDocument(item.id);
    if (document == null || !mounted) return;
    final preset = await repository.loadPreset('script:${item.id}');
    final bundle = ScriptBundle.fromDocuments(
      [document],
      presets: {item.id: preset},
    );
    final bytes = Uint8List.fromList(utf8.encode(bundle.encode()));
    final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final saved = await FilePicker.saveFile(
      fileName: '${safeName.isEmpty ? 'script' : safeName}.tps',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: l10n.homeMenuExport,
    );
    if (!mounted) return;
    if (saved == null) {
      _toast(l10n.homeExportCanceled);
      return;
    }
    AppLog.instance.event('home', 'export_tps', {
      'script': item.id,
      'bytes': bytes.length,
    });
    _toast(l10n.homeExportDone(item.title));
  }

  Future<void> _exportAll() async {
    final l10n = AppLocalizations.of(context);
    final bundle = await ref.read(scriptRepositoryProvider).exportBundle();
    if (!mounted) return;
    if (bundle == null) {
      _toast(l10n.homeExportEmpty);
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(bundle.encode()));
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final saved = await FilePicker.saveFile(
      fileName: 'teleprompter-$stamp.tps',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: l10n.homeMenuExportAll,
    );
    if (!mounted) return;
    if (saved == null) {
      _toast(l10n.homeExportCanceled);
      return;
    }
    AppLog.instance.event('home', 'export_all', {
      'scripts': bundle.scriptCount,
      'bytes': bytes.length,
    });
    _toast(l10n.homeExportAllDone(bundle.scriptCount));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ScriptTile extends StatelessWidget {
  const _ScriptTile({
    required this.item,
    required this.inTrash,
    required this.onOpen,
    required this.onAction,
  });

  final ScriptSummary item;
  final bool inTrash;
  final VoidCallback? onOpen;
  final void Function(_ScriptAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final updated = _formatTime(item.updatedAt, l10n);
    final lastViewed = item.lastViewedAt;
    final subtitle = [
      l10n.homeMetaChars(item.charCount, updated),
      if (lastViewed != null)
        l10n.homeLastViewed(_formatTime(lastViewed, l10n)),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TpTokens.space3,
          vertical: TpTokens.space1,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (item.favorite)
              Icon(Icons.star, size: 16, color: theme.colorScheme.tertiary),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (item.preview.isNotEmpty) ...[
              const SizedBox(height: TpTokens.space1),
              Text(
                item.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<_ScriptAction>(
          tooltip: l10n.homeMore,
          onSelected: onAction,
          itemBuilder: (context) => inTrash
              ? [
                  PopupMenuItem(
                    value: _ScriptAction.restore,
                    child: Text(l10n.homeMenuRestore),
                  ),
                  PopupMenuItem(
                    value: _ScriptAction.purge,
                    child: Text(l10n.homeMenuPurge),
                  ),
                ]
              : [
                  PopupMenuItem(
                    value: _ScriptAction.edit,
                    child: Text(l10n.homeMenuEdit),
                  ),
                  PopupMenuItem(
                    value: _ScriptAction.rename,
                    child: Text(l10n.homeRenameTitle),
                  ),
                  PopupMenuItem(
                    value: item.favorite
                        ? _ScriptAction.unfavorite
                        : _ScriptAction.favorite,
                    child: Text(
                      item.favorite
                          ? l10n.homeMenuUnfavorite
                          : l10n.homeMenuFavorite,
                    ),
                  ),
                  PopupMenuItem(
                    value: item.archived
                        ? _ScriptAction.unarchive
                        : _ScriptAction.archive,
                    child: Text(
                      item.archived
                          ? l10n.homeMenuUnarchive
                          : l10n.homeMenuArchive,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ScriptAction.duplicate,
                    child: Text(l10n.homeMenuDuplicate),
                  ),
                  PopupMenuItem(
                    value: _ScriptAction.export,
                    child: Text(l10n.homeMenuExport),
                  ),
                  PopupMenuItem(
                    value: _ScriptAction.delete,
                    child: Text(l10n.homeMenuDelete),
                  ),
                ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp, AppLocalizations l10n) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final diff = today.difference(date).inDays;
    final clock = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return clock;
    if (diff == 1) return l10n.homeYesterday;
    if (diff < 7) return l10n.homeDaysAgo(diff);
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
  }
}
