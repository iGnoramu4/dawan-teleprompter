import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'recording_format.dart';

/// 录制历史面板（E8-2/E8-3）：复盘、导出、删除。
Future<void> showRecordingHistorySheet({
  required BuildContext context,
  required List<RecordingEntry> entries,
  required void Function(RecordingEntry entry) onReplay,
  required Future<void> Function(RecordingEntry entry) onExport,
  required Future<List<RecordingEntry>> Function(RecordingEntry entry) onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Theme(
      data: TpTheme.dark(),
      child: RecordingHistorySheet(
        entries: entries,
        onReplay: onReplay,
        onExport: onExport,
        onDelete: onDelete,
      ),
    ),
  );
}

class RecordingHistorySheet extends StatefulWidget {
  const RecordingHistorySheet({
    super.key,
    required this.entries,
    required this.onReplay,
    required this.onExport,
    required this.onDelete,
  });

  final List<RecordingEntry> entries;
  final void Function(RecordingEntry entry) onReplay;
  final Future<void> Function(RecordingEntry entry) onExport;
  final Future<List<RecordingEntry>> Function(RecordingEntry entry) onDelete;

  @override
  State<RecordingHistorySheet> createState() => _RecordingHistorySheetState();
}

class _RecordingHistorySheetState extends State<RecordingHistorySheet> {
  late List<RecordingEntry> _entries = widget.entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpTokens.space4,
              TpTokens.space2,
              TpTokens.space4,
              TpTokens.space2,
            ),
            child: Text(
              l10n.recordHistory,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(TpTokens.space6),
              child: Text(
                l10n.recordNone,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _entries.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    key: ValueKey('recording-${entry.id}'),
                    leading: const Icon(Icons.multitrack_audio),
                    title: Text(l10n.recordDuration(
                      formatRecordingDuration(entry.durationMs),
                    )),
                    subtitle: Text(
                      '${_date(entry.createdAt)} · '
                      '${formatRecordingSize(entry.sizeBytes)}',
                    ),
                    onTap: () => _replay(entry),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.recordReplay,
                          icon: const Icon(Icons.play_circle_outline),
                          onPressed: () => _replay(entry),
                        ),
                        IconButton(
                          tooltip: l10n.recordExport,
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _export(entry),
                        ),
                        IconButton(
                          tooltip: l10n.recordDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(entry),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _replay(RecordingEntry entry) {
    Navigator.of(context).pop();
    widget.onReplay(entry);
  }

  Future<void> _export(RecordingEntry entry) async {
    await widget.onExport(entry);
  }

  Future<void> _delete(RecordingEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.recordDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.remoteClose),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.recordDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = await widget.onDelete(entry);
    if (!mounted) return;
    setState(() => _entries = updated);
  }

  static String _date(int createdAt) {
    final stamp = DateTime.fromMillisecondsSinceEpoch(createdAt);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${stamp.year}-${two(stamp.month)}-${two(stamp.day)} '
        '${two(stamp.hour)}:${two(stamp.minute)}';
  }
}
