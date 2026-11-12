import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_routes.dart';
import '../../data/app_log.dart';
import '../../data/appearance_settings.dart';
import '../../data/backup_service.dart';
import '../../data/lan_transfer.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/asr_lab/asr_lab_settings.dart';
import '../../shared/reader_settings/reader_bar_settings.dart';
import '../../shared/reader_settings/reader_defaults_store.dart';
import '../../shared/reader_settings/reader_settings.dart';
import '../../shared/reader_settings/reader_settings_sheet.dart';
import 'asr_lab_page.dart';

/// 全局设置页（M1-c）：默认阅读参数 + 诊断日志导出。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  ReaderSettings _defaults = ReaderSettings.defaults;
  List<ReaderBarAction> _barActions = defaultReaderBarActions;
  bool _loaded = false;
  bool _exporting = false;
  bool _backupBusy = false;
  BackupInfo? _latestBackup;
  int _backupCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final items =
        await BackupService(ref.read(scriptRepositoryProvider)).list();
    if (!mounted) return;
    setState(() {
      _backupCount = items.length;
      _latestBackup = items.isEmpty ? null : items.first;
    });
  }

  Future<void> _backupNow() async {
    if (_backupBusy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _backupBusy = true);
    try {
      final backup =
          await BackupService(ref.read(scriptRepositoryProvider)).backupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backup == null ? l10n.settingsBackupEmpty : l10n.settingsBackupDone,
          ),
        ),
      );
      AppLog.instance.event('settings', 'backup_created', {
        'result': backup == null ? 'empty' : 'ok',
        if (backup != null) 'bytes': backup.sizeBytes,
      });
      await _loadBackups();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsBackupFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _exportBackup() async {
    final latest = _latestBackup;
    if (latest == null) return;
    final l10n = AppLocalizations.of(context);
    final bytes = await latest.file.readAsBytes();
    if (!mounted) return;
    final uri = await FilePicker.saveFile(
      dialogTitle: l10n.settingsBackupExport,
      fileName: latest.name,
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uri == null
              ? l10n.settingsExportCanceled
              : l10n.settingsBackupExportDone(uri.toString()),
        ),
      ),
    );
    AppLog.instance.event('settings', 'backup_exported', {
      'result': uri == null ? 'cancelled' : 'ok',
    });
  }

  Future<void> _loadDefaults() async {
    final repository = ref.read(scriptRepositoryProvider);
    final loaded = await loadGlobalReaderDefaults(repository);
    final barActions = await loadReaderBarActions(repository);
    if (!mounted) return;
    setState(() {
      _defaults = loaded ?? ReaderSettings.defaults;
      _barActions = barActions;
      _loaded = true;
    });
  }

  Future<void> _saveDefaults(ReaderSettings settings) async {
    setState(() => _defaults = settings.normalized());
    final repository = ref.read(scriptRepositoryProvider);
    await saveGlobalReaderDefaults(repository, _defaults);
    AppLog.instance.event('settings', 'reader_defaults_saved', {
      'fontSize': _defaults.fontSize,
      'lineHeight': _defaults.lineHeight,
      'theme': _defaults.theme.name,
      'speed': _defaults.speed,
    });
  }

  Future<void> _openReaderDefaults() async {
    await showReaderSettingsSheet(
      context: context,
      settings: _defaults,
      onChanged: _saveDefaults,
      onSaveAsDefault: (settings) async {
        await _saveDefaults(settings);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).settingsSavedDefault)),
        );
      },
    );
  }

  Future<void> _resetDefaults() async {
    await _saveDefaults(ReaderSettings.defaults);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).settingsRestored)),
    );
  }

  /// 选择提词页功能栏默认显示哪些按钮；返回/设置/隐藏固定显示。
  Future<void> _openBarActions() async {
    final l10n = AppLocalizations.of(context);
    final selected = {..._barActions};
    final result = await showDialog<Set<ReaderBarAction>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.settingsBarItems),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsBarItemsHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final action in ReaderBarAction.values)
                      FilterChip(
                        label: Text(_barActionLabel(l10n, action)),
                        selected: selected.contains(action),
                        onSelected: (on) {
                          setDialogState(() {
                            if (on) {
                              selected.add(action);
                            } else {
                              selected.remove(action);
                            }
                          });
                        },
                      ),
                  ],
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
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final ordered = [
      for (final action in ReaderBarAction.values)
        if (result.contains(action)) action,
    ];
    setState(() => _barActions = ordered);
    await saveReaderBarActions(
      ref.read(scriptRepositoryProvider),
      ordered,
    );
  }

  String _barActionLabel(AppLocalizations l10n, ReaderBarAction action) {
    return switch (action) {
      ReaderBarAction.prev => l10n.barActionPrev,
      ReaderBarAction.next => l10n.barActionNext,
      ReaderBarAction.playPause => l10n.barActionPlayPause,
      ReaderBarAction.speed => l10n.barActionSpeed,
      ReaderBarAction.fontSize => l10n.barActionFontSize,
      ReaderBarAction.mic => l10n.barActionMic,
      ReaderBarAction.restart => l10n.barActionRestart,
      ReaderBarAction.overlay => l10n.barActionOverlay,
      ReaderBarAction.remote => l10n.barActionRemote,
      ReaderBarAction.display => l10n.barActionDisplay,
      ReaderBarAction.record => l10n.barActionRecord,
      ReaderBarAction.history => l10n.barActionHistory,
      ReaderBarAction.lock => l10n.barActionLock,
    };
  }

  Future<void> _exportDiagnostics() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final logs = await AppLog.instance.readAll();
      final now = DateTime.now();
      final stamp = now
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '')
          .replaceAll('-', '');
      final asrLab =
          await loadAsrLabSettings(ref.read(scriptRepositoryProvider));
      // 不写入本地文件路径等环境标识（CODING §7）。
      final header = jsonEncode({
        'exportedAt': now.toIso8601String(),
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'readerDefaults': _defaults.toJson(),
        'asrLab': asrLab.toJson(),
      });
      final content = StringBuffer()
        ..writeln('# teleprompter diagnostics')
        ..writeln(header)
        ..writeln('# logs')
        ..write(logs);

      final uri = await FilePicker.saveFile(
        dialogTitle: l10n.settingsExportDiagnostics,
        fileName: 'teleprompter-diag-$stamp.txt',
        mimeType: 'text/plain',
        bytes: utf8.encode(content.toString()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uri == null
                ? l10n.settingsExportCanceled
                : l10n.settingsExportDone(uri.toString()),
          ),
        ),
      );
      // 只记录结果状态，不记录路径。
      AppLog.instance.event('settings', 'diagnostics_exported', {
        'result': uri == null ? 'cancelled' : 'ok',
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsExportFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recent = AppLog.instance.recent;
    final appearance = ref.watch(appearanceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          TpTokens.space3,
          TpTokens.space3,
          TpTokens.space3,
          TpTokens.space8,
        ),
        children: [
          _sectionTitle(theme, l10n.settingsSectionAppearance),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TpTokens.space4,
                    TpTokens.space3,
                    TpTokens.space4,
                    TpTokens.space2,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsThemeMode,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TpTokens.space4,
                  ),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.themeModeSystem),
                        icon: const Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.themeModeLight),
                        icon: const Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeModeDark),
                        icon: const Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {appearance.mode},
                    onSelectionChanged: (values) => _setThemeMode(values.first),
                  ),
                ),
                const Divider(height: TpTokens.space6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TpTokens.space4,
                    0,
                    TpTokens.space4,
                    TpTokens.space2,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsAccentColor,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TpTokens.space2,
                  ),
                  child: Row(
                    children: [
                      for (final accent in TpAccent.values)
                        _accentSwatch(
                          theme,
                          accent,
                          _accentLabel(l10n, accent),
                          accent == appearance.accent,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TpTokens.space4,
                    TpTokens.space2,
                    TpTokens.space4,
                    TpTokens.space3,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsAppearanceNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TpTokens.space4),
          _sectionTitle(theme, l10n.settingsSectionReading),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: Text(l10n.settingsGlobalDefaults),
                  subtitle: _loaded
                      ? Text(
                          l10n.settingsDefaultsSummary(
                            _themeLabel(l10n, _defaults.theme),
                            _defaults.fontSize.toInt(),
                            _defaults.lineHeight.toStringAsFixed(2),
                            _defaults.speed.toStringAsFixed(1),
                          ),
                        )
                      : Text(l10n.commonLoading),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _loaded ? _openReaderDefaults : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: Text(l10n.settingsRestoreDefaults),
                  subtitle: Text(l10n.settingsRestoreHint),
                  onTap: _loaded ? _resetDefaults : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: Text(l10n.settingsBarItems),
                  subtitle: Text(
                    l10n.settingsBarItemsSummary(
                      _barActions
                          .map((action) => _barActionLabel(l10n, action))
                          .join('、'),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _loaded ? _openBarActions : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: TpTokens.space2),
            child: Text(
              l10n.settingsDefaultsNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: TpTokens.space4),
          _sectionTitle(theme, l10n.settingsSectionTransfer),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: Text(l10n.settingsLanTransfer),
                  subtitle: Text(l10n.settingsLanTransferHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openLanTransfer,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cast_connected),
                  title: Text(l10n.remoteTitle),
                  subtitle: Text(l10n.remoteEntryHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.remote),
                ),
              ],
            ),
          ),
          const SizedBox(height: TpTokens.space4),
          _sectionTitle(theme, l10n.settingsSectionDiagnostics),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.settingsExportDiagnostics),
                  subtitle: Text(
                    AppLog.instance.enabled
                        ? l10n.settingsExportContains
                        : l10n.settingsExportNoLogs,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share),
                  onTap: _exporting ? null : _exportDiagnostics,
                ),
              ],
            ),
          ),
          const SizedBox(height: TpTokens.space3),
          Text(
            l10n.settingsRecentLogs(recent.length),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: TpTokens.space1),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.all(TpTokens.space2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
            ),
            child: recent.isEmpty
                ? Text(l10n.settingsNoLogs, style: theme.textTheme.bodySmall)
                : SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      recent.reversed.take(12).join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: TpTokens.space4),
          _sectionTitle(theme, l10n.settingsSectionBackup),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l10n.settingsBackupNow),
                  subtitle: Text(
                    _latestBackup == null
                        ? l10n.settingsBackupNone
                        : '${l10n.settingsBackupLatest(
                            _formatBackupTime(_latestBackup!.createdAt),
                            _formatSize(_latestBackup!.sizeBytes),
                          )} · ${l10n.settingsBackupCount(_backupCount)}',
                  ),
                  trailing: _backupBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onTap: _backupBusy ? null : _backupNow,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: Text(l10n.settingsBackupExport),
                  subtitle: Text(l10n.settingsAutoBackupHint),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: _latestBackup != null,
                  onTap: _latestBackup == null ? null : _exportBackup,
                ),
              ],
            ),
          ),
          if (!kReleaseMode) ...[
            const SizedBox(height: TpTokens.space4),
            _sectionTitle(theme, l10n.settingsSectionDeveloper),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(l10n.settingsAsrLab),
                subtitle: Text(l10n.settingsAsrLabHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAsrLab,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAsrLab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AsrLabPage()),
    );
  }

  Future<void> _openLanTransfer() async {
    final l10n = AppLocalizations.of(context);
    final server = LanTransferServer(ref.read(scriptRepositoryProvider));
    final String url;
    try {
      url = await server.start(
        LanTransferLabels(
          title: l10n.lanPageTitle,
          hint: l10n.lanPageHint,
          downloadAll: l10n.lanDownloadAll,
          scriptList: l10n.lanScriptList,
          noScripts: l10n.lanNoScripts,
          importTitle: l10n.lanImportTitle,
          importButton: l10n.lanImportButton,
          importDone: l10n.lanImportDone,
          importFailed: l10n.lanImportFailed,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsLanTransferFailed('$error'))),
      );
      return;
    }
    if (!mounted) {
      await server.stop();
      return;
    }
    AppLog.instance.event('settings', 'lan_transfer_started', {
      'port': server.port,
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsLanTransferTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: url,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: TpTokens.space3),
              SelectableText(url, textAlign: TextAlign.center),
              const SizedBox(height: TpTokens.space2),
              Text(
                l10n.settingsLanTransferStop,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
    await server.stop();
    AppLog.instance.event('settings', 'lan_transfer_stopped');
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final current = ref.read(appearanceProvider);
    if (current.mode == mode) return;
    await _applyAppearance(
      current.copyWith(mode: mode),
      {'mode': mode.name},
    );
  }

  Future<void> _setAccent(TpAccent accent) async {
    final current = ref.read(appearanceProvider);
    if (current.accent == accent) return;
    await _applyAppearance(
      current.copyWith(accent: accent),
      {'accent': accent.id},
    );
  }

  Future<void> _applyAppearance(
    AppearanceSettings next,
    Map<String, Object?> logData,
  ) async {
    ref.read(appearanceProvider.notifier).state = next;
    await saveAppearanceSettings(ref.read(scriptRepositoryProvider), next);
    AppLog.instance.event('settings', 'appearance_changed', logData);
  }

  String _accentLabel(AppLocalizations l10n, TpAccent accent) =>
      switch (accent) {
        TpAccent.indigo => l10n.accentIndigo,
        TpAccent.teal => l10n.accentTeal,
        TpAccent.amber => l10n.accentAmber,
        TpAccent.rose => l10n.accentRose,
      };

  Widget _accentSwatch(
    ThemeData theme,
    TpAccent accent,
    String label,
    bool selected,
  ) {
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: () => _setAccent(accent),
          radius: TpTokens.touchTarget / 2,
          child: SizedBox(
            width: TpTokens.touchTarget,
            height: TpTokens.touchTarget,
            child: Center(
              child: Container(
                width: TpTokens.space6 + TpTokens.space1,
                height: TpTokens.space6 + TpTokens.space1,
                decoration: BoxDecoration(
                  color: accent.seed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBackupTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TpTokens.space1),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ReaderTheme theme) =>
      theme == ReaderTheme.stageWhite
          ? l10n.readerThemeWhite
          : l10n.readerThemeDark;
}
