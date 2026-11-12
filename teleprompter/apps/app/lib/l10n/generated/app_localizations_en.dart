// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dawan Teleprompter';

  @override
  String get appScriptsTitle => 'Scripts';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get homeSearchHint => 'Search title or content';

  @override
  String get homeSearch => 'Search';

  @override
  String get homeSearchClose => 'Close search';

  @override
  String get homeSortTooltip => 'Sort';

  @override
  String get homeSortUpdated => 'Recently updated';

  @override
  String get homeSortCreated => 'Recently created';

  @override
  String get homeSortTitle => 'Title';

  @override
  String get homeSortChars => 'Characters';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String homeErrorLoad(String error) {
    return 'Failed to load scripts: $error';
  }

  @override
  String get homeViewAll => 'All';

  @override
  String get homeViewFavorite => 'Favorites';

  @override
  String get homeViewArchived => 'Archived';

  @override
  String get homeViewTrash => 'Trash';

  @override
  String get homeEmptyActiveTitle => 'No scripts yet';

  @override
  String get homeEmptyActiveHint => 'Create one, or paste/import a file';

  @override
  String get homeEmptyFavoriteTitle => 'No favorites';

  @override
  String get homeEmptyFavoriteHint => 'Add favorites from the script menu';

  @override
  String get homeEmptyArchivedTitle => 'No archived scripts';

  @override
  String get homeEmptyArchivedHint => 'Archived scripts appear here';

  @override
  String get homeEmptyTrashTitle => 'Trash is empty';

  @override
  String get homeEmptyTrashHint => 'Deleted scripts are kept for 30 days';

  @override
  String get homeNew => 'New';

  @override
  String get homeCreateBlank => 'New blank script';

  @override
  String get homeCreateBlankHint => 'Start typing in the editor';

  @override
  String get homeCreatePaste => 'Paste import';

  @override
  String get homeCreatePasteHint => 'Paste from clipboard, keep line breaks';

  @override
  String get homeCreateFile => 'Import from file';

  @override
  String get homeCreateFileHint =>
      'Supports .txt / .md / .tps / .docx / .pdf; text auto-detects UTF-8 / GBK';

  @override
  String get homeRenameTitle => 'Rename';

  @override
  String get homeTitleLabel => 'Title';

  @override
  String get homePurgeTitle => 'Delete permanently';

  @override
  String homePurgeConfirm(String title) {
    return '\"$title\" and its markers will be deleted permanently. This cannot be undone.';
  }

  @override
  String homeCopied(String title) {
    return 'Copied \"$title\"';
  }

  @override
  String homeMovedToTrash(String title) {
    return '\"$title\" moved to trash';
  }

  @override
  String homeRestored(String title) {
    return 'Restored \"$title\"';
  }

  @override
  String homePurged(String title) {
    return 'Permanently deleted \"$title\"';
  }

  @override
  String get homeMore => 'More';

  @override
  String get homeMenuEdit => 'Edit';

  @override
  String get homeMenuFavorite => 'Favorite';

  @override
  String get homeMenuUnfavorite => 'Remove favorite';

  @override
  String get homeMenuArchive => 'Archive';

  @override
  String get homeMenuUnarchive => 'Unarchive';

  @override
  String get homeMenuDuplicate => 'Duplicate';

  @override
  String get homeMenuExport => 'Export .tps';

  @override
  String get homeMenuExportAll => 'Export all (.tps)';

  @override
  String get homeExportEmpty => 'No scripts to export';

  @override
  String homeExportAllDone(int count) {
    return 'Exported $count script(s)';
  }

  @override
  String homeExportDone(String title) {
    return 'Exported \"$title\"';
  }

  @override
  String get homeExportCanceled => 'Export canceled';

  @override
  String get homeImportTpsTitle => 'Import .tps';

  @override
  String homeImportTpsConfirm(int count) {
    return 'Import $count script(s) with markers?';
  }

  @override
  String homeImportTpsDone(int count) {
    return 'Imported $count script(s)';
  }

  @override
  String get homeImportTpsInvalid => 'Unrecognized .tps file';

  @override
  String get homeImportUnsupported =>
      'Only .txt / .md / .tps / .docx / .pdf files are supported';

  @override
  String get homeImportParseFailed =>
      'Could not extract text from this file (scanned PDFs are not supported yet)';

  @override
  String get homeMenuDelete => 'Move to trash';

  @override
  String get homeMenuRestore => 'Restore';

  @override
  String get homeMenuPurge => 'Delete permanently';

  @override
  String get homeClipboardEmpty => 'Clipboard is empty';

  @override
  String get homeClipboardSource => 'Clipboard';

  @override
  String homeMetaChars(int charCount, String updated) {
    return '$charCount chars · $updated';
  }

  @override
  String homeLastViewed(String time) {
    return 'Last $time';
  }

  @override
  String get homeYesterday => 'Yesterday';

  @override
  String homeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String importPreviewTitle(String source) {
    return 'Import preview · $source';
  }

  @override
  String get importDefaultSource => 'Import';

  @override
  String get importTitleLabel => 'Title';

  @override
  String get importMergeHardBreaks => 'Merge hard line breaks';

  @override
  String get importMergeHardBreaksHint =>
      'Rejoin sentences broken by PDF/web copy';

  @override
  String get importStripHeaders => 'Remove page numbers/headers';

  @override
  String get importNormalizeWidth => 'Full-width to half-width';

  @override
  String get importStripMarkdown => 'Strip Markdown markup';

  @override
  String importCleanedStats(int charCount) {
    return 'Cleaned: $charCount chars';
  }

  @override
  String get importEmptyPreview => '(empty)';

  @override
  String get importRawEditable => 'Raw text (editable)';

  @override
  String get importSaveAndEdit => 'Save and edit';

  @override
  String get importSaveAndPrompt => 'Save and prompt';

  @override
  String get importNoContent => 'Nothing to save';

  @override
  String get editorUnnamedScript => 'Untitled script';

  @override
  String get editorTitle => 'Edit script';

  @override
  String get editorStatusUnsaved => 'Unsaved';

  @override
  String get editorStatusAutoSave => 'Autosave';

  @override
  String get editorStatusSaved => 'Saved';

  @override
  String get editorPrompt => 'Prompt';

  @override
  String get editorTitleHint => 'Script title';

  @override
  String editorStatsChars(int chars) {
    return '$chars chars';
  }

  @override
  String get editorAddMarker => 'Add marker';

  @override
  String get editorSectionHint => 'Script text';

  @override
  String get editorMarkNeedText => 'Enter script text first';

  @override
  String get editorMarkerDialogTitle => 'Add marker';

  @override
  String editorMarkerOffset(int offset) {
    return 'Character $offset';
  }

  @override
  String get editorMarkerLabel => 'Note (optional)';

  @override
  String editorMarkerAt(String kind, int offset) {
    return '$kind @$offset';
  }

  @override
  String editorSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get editorMissing => 'Script not found or deleted';

  @override
  String get markerEmphasis => 'Emphasis';

  @override
  String get markerPause => 'Pause';

  @override
  String get markerBreath => 'Breath';

  @override
  String get markerAction => 'Action';

  @override
  String get markerTime => 'Timecode';

  @override
  String get markerCustom => 'Custom';

  @override
  String get readerBack => 'Back';

  @override
  String get readerPrevSentence => 'Previous line';

  @override
  String get readerNextSentence => 'Next line';

  @override
  String get readerPause => 'Pause';

  @override
  String get readerResume => 'Resume';

  @override
  String get readerVoiceOff => 'Voice follow';

  @override
  String get readerVoiceOn => 'Stop voice follow';

  @override
  String get readerReplayTooltip => 'Replay test audio (dev builds only)';

  @override
  String get readerHidePanel => 'Hide toolbar';

  @override
  String get readerShowPanel => 'Show toolbar';

  @override
  String get readerRestart => 'Back to start';

  @override
  String get readerSettings => 'Reading settings';

  @override
  String get readerLock => 'Lock (block gestures)';

  @override
  String get readerLockedBadge => 'Locked · tap to unlock';

  @override
  String get readerOverlay => 'Floating prompt';

  @override
  String get overlayOpenTooltip => 'Floating prompt (over other apps)';

  @override
  String get overlayCloseTooltip => 'Close floating prompt';

  @override
  String get overlayPermissionTitle => 'Overlay permission required';

  @override
  String get overlayPermissionBody =>
      'Allow display over other apps to keep the script visible while using other apps. The system settings page will open next; return after granting.';

  @override
  String get overlayPermissionAction => 'Grant';

  @override
  String get overlayPermissionDenied =>
      'Overlay permission denied; in-app prompting remains available';

  @override
  String get overlayNotificationTitle => 'Dawan Teleprompter overlay';

  @override
  String get overlayNotificationDenied =>
      'Notification permission denied: the overlay still works, but the foreground notification is hidden';

  @override
  String get overlayWaiting => 'Waiting for script…';

  @override
  String readerProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String readerLineRate(String speed) {
    return '$speed lines/s';
  }

  @override
  String get readerVoicePreparing => 'Preparing…';

  @override
  String get readerReplayPreparing => 'Preparing replay…';

  @override
  String get readerSavedAsDefault => 'Saved as global default';

  @override
  String readerMicStartFailed(String error) {
    return 'Failed to start voice follow: $error';
  }

  @override
  String get readerModelInstallFailed =>
      'Offline model installation failed. Tap Retry to reinstall; incomplete files were cleaned up.';

  @override
  String get readerModelInstallFailedUnclean =>
      'Offline model installation failed. Tap Retry to reinstall; incomplete files could not be cleaned up, please check free storage first.';

  @override
  String get actionRetry => 'Retry';

  @override
  String readerReplayStartFailed(String error) {
    return 'Failed to start replay: $error';
  }

  @override
  String get voiceRequestingMic => 'Requesting microphone…';

  @override
  String get voiceFollowingMic => 'Following (microphone)';

  @override
  String voiceAudioError(String error) {
    return 'Audio capture failed: $error';
  }

  @override
  String voiceReplayStatus(String seconds) {
    return 'Replaying test audio ($seconds s)';
  }

  @override
  String get voiceReplayDone => 'Replay finished';

  @override
  String voiceReplayFailed(String error) {
    return 'Replay failed: $error';
  }

  @override
  String get voiceInstallModel => 'Installing offline model…';

  @override
  String voiceInstallModelProgress(int percent, int done, int total) {
    return 'Installing offline model… $percent% ($done / $total MB)';
  }

  @override
  String get voiceLoadingRecognizer =>
      'Loading recognizer… (usually a few seconds)';

  @override
  String voiceReady(String ms) {
    return 'Recognizer ready (loaded in $ms ms)';
  }

  @override
  String voiceRecognitionFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionReading => 'Reading';

  @override
  String get settingsBarItems => 'Toolbar buttons';

  @override
  String get settingsBarItemsHint =>
      'Choose which buttons appear by default in the prompt toolbar; back, settings and hide are always shown.';

  @override
  String settingsBarItemsSummary(String items) {
    return 'Showing: $items';
  }

  @override
  String get barActionPrev => 'Previous line';

  @override
  String get barActionNext => 'Next line';

  @override
  String get barActionPlayPause => 'Play/pause';

  @override
  String get barActionSpeed => 'Scroll speed';

  @override
  String get barActionFontSize => 'Font size';

  @override
  String get barActionMic => 'Voice follow';

  @override
  String get barActionRestart => 'Start over';

  @override
  String get barActionOverlay => 'Floating window';

  @override
  String get barActionRemote => 'Remote';

  @override
  String get barActionDisplay => 'External display';

  @override
  String get barActionRecord => 'Record';

  @override
  String get barActionHistory => 'Recording history';

  @override
  String get barActionLock => 'Lock';

  @override
  String get settingsGlobalDefaults => 'Global default reading settings';

  @override
  String settingsDefaultsSummary(
      String theme, int fontSize, String lineHeight, String speed) {
    return '$theme · $fontSize px · line height $lineHeight× · $speed lines/s';
  }

  @override
  String get settingsRestoreDefaults => 'Restore defaults';

  @override
  String get settingsRestoreHint => 'Does not affect per-script settings';

  @override
  String get settingsDefaultsNote =>
      'New or unremembered scripts use these settings; scripts with saved settings keep their own.';

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsBackupNow => 'Back up now';

  @override
  String get settingsAutoBackupHint =>
      'Automatically backs up on first launch each day to app storage; keeps the latest 7';

  @override
  String settingsBackupLatest(String time, String size) {
    return 'Last backup: $time · $size';
  }

  @override
  String settingsBackupCount(int count) {
    return '$count backup(s)';
  }

  @override
  String get settingsBackupNone => 'No backups yet';

  @override
  String get settingsBackupDone => 'Backup complete';

  @override
  String get settingsBackupEmpty => 'No scripts to back up';

  @override
  String settingsBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get settingsBackupExport => 'Export latest backup';

  @override
  String settingsBackupExportDone(String uri) {
    return 'Backup exported: $uri';
  }

  @override
  String get settingsSectionTransfer => 'Transfer';

  @override
  String get settingsLanTransfer => 'LAN transfer';

  @override
  String get settingsLanTransferHint =>
      'Download all scripts or upload a .tps from a browser on the same Wi-Fi';

  @override
  String get settingsLanTransferTitle => 'LAN transfer';

  @override
  String get settingsLanTransferStop =>
      'Closing this dialog stops the service. The URL contains a random token; do not share it with untrusted devices.';

  @override
  String settingsLanTransferFailed(String error) {
    return 'Failed to start: $error';
  }

  @override
  String get lanPageTitle => 'Dawan Teleprompter · LAN transfer';

  @override
  String get lanPageHint =>
      'Open this page on the same Wi-Fi; the service stops when the phone dialog closes.';

  @override
  String get lanDownloadAll => 'Download all scripts (.tps)';

  @override
  String get lanScriptList => 'Scripts';

  @override
  String get lanNoScripts => 'No scripts to download';

  @override
  String get lanImportTitle => 'Import a script bundle';

  @override
  String get lanImportButton => 'Choose .tps and import';

  @override
  String lanImportDone(int count) {
    return 'Imported $count script(s)';
  }

  @override
  String get lanImportFailed => 'Import failed: invalid file';

  @override
  String get settingsSectionDiagnostics => 'Diagnostics';

  @override
  String get settingsExportDiagnostics => 'Export diagnostics';

  @override
  String get settingsExportContains => 'Includes run logs and reading settings';

  @override
  String get settingsExportNoLogs => 'Logs not initialized (settings only)';

  @override
  String get settingsExportCanceled => 'Export canceled';

  @override
  String settingsExportDone(String uri) {
    return 'Diagnostics exported: $uri';
  }

  @override
  String settingsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String settingsRecentLogs(int count) {
    return 'Recent logs ($count)';
  }

  @override
  String get settingsNoLogs => 'No logs';

  @override
  String get settingsRestored => 'Default reading settings restored';

  @override
  String get settingsSavedDefault => 'Saved as global default';

  @override
  String get readerThemeDark => 'Stage dark';

  @override
  String get readerThemeWhite => 'High-contrast white';

  @override
  String get sheetTitle => 'Reading settings';

  @override
  String get sheetSaveAsDefault => 'Save as global default';

  @override
  String get sheetRestoreDefaults => 'Restore defaults';

  @override
  String get sheetSectionVisual => 'Visual';

  @override
  String get sheetFontSize => 'Font size';

  @override
  String get sheetLineHeight => 'Line height';

  @override
  String get sheetMarginLeft => 'Left margin';

  @override
  String get sheetMarginRight => 'Right margin';

  @override
  String get sheetCharsPerLine => 'Chars per line (auto)';

  @override
  String get sheetCharsAutoHint =>
      'Computed from screen width, font size and letter spacing; reflows on rotate/resize';

  @override
  String sheetCharsAutoValue(int count) {
    return 'About $count chars now, adapts to the window';
  }

  @override
  String get sheetSectionMatch => 'Speech match tolerance';

  @override
  String get sheetMatchHint =>
      'Loosen in noisy rooms or ad-libbing; tighten if it jumps ahead';

  @override
  String get matchVeryStrict => 'Most cautious';

  @override
  String get matchVeryStrictHint =>
      'Advances only after a full line is heard; almost never jumps ahead.';

  @override
  String get matchStrict => 'Strict';

  @override
  String get matchStrictHint =>
      'Better to lag a little than jump ahead; good for quiet, scripted reading.';

  @override
  String get matchStandard => 'Standard';

  @override
  String get matchStandardHint =>
      'Default balance of follow speed and stability.';

  @override
  String get matchLoose => 'Loose';

  @override
  String get matchLooseHint =>
      'Follows more easily in noisy rooms or when ad-libbing.';

  @override
  String get matchVeryLoose => 'Most loose';

  @override
  String get matchVeryLooseHint =>
      'Keeps up through noise and improvising, may occasionally run slightly ahead.';

  @override
  String get sheetLetterSpacing => 'Letter spacing';

  @override
  String get sheetAlignCenter => 'Center align';

  @override
  String get sheetAlignCenterHint => 'Left aligned / centered';

  @override
  String get sheetSectionMirror => 'Mirror & beamsplitter';

  @override
  String get sheetMirrorX => 'Horizontal mirror';

  @override
  String get sheetMirrorXHint => 'Beamsplitter / reflective prompter';

  @override
  String get sheetMirrorY => 'Vertical mirror';

  @override
  String get sheetPrismDx => 'Beamsplitter horizontal calibration';

  @override
  String get sheetPrismDy => 'Beamsplitter vertical calibration';

  @override
  String get sheetSectionScroll => 'Scrolling & follow';

  @override
  String get sheetSpeed => 'Constant speed';

  @override
  String get sheetSpeedReset => 'Reset speed (1.2 lines/s)';

  @override
  String get sheetReadAhead => 'Reading band position (% of screen)';

  @override
  String get sheetSmoothness => 'Smoothness';

  @override
  String get sheetPauseStop => 'Stop on pause';

  @override
  String get sheetPauseStopHint => 'Do not scroll while recognition stalls';

  @override
  String get sheetKeepScreenOn => 'Keep screen on';

  @override
  String get sheetKeepScreenOnHint =>
      'Do not turn off the screen while reading';

  @override
  String get sheetSectionOverlay => 'Floating prompt';

  @override
  String get sheetOverlayWidth => 'Window width';

  @override
  String sheetOverlayWidthValue(int width) {
    return '$width dp';
  }

  @override
  String get sheetOverlayOpacity => 'Opacity';

  @override
  String get sheetOverlayLines => 'Visible lines';

  @override
  String get sheetOverlayLines3 => '3 lines';

  @override
  String get sheetOverlayLines5 => '5 lines';

  @override
  String get sheetOverlayHint =>
      'Affects the floating window only, not the main reading canvas. The window always follows the current line.';

  @override
  String get sheetFooter =>
      'Settings are remembered per script (§4.3 C-06) and restored when switching.';

  @override
  String sheetFontSizeValue(int size) {
    return '$size px';
  }

  @override
  String sheetLineHeightValue(String value) {
    return '$value×';
  }

  @override
  String sheetPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String sheetCharsValue(int count) {
    return '$count chars';
  }

  @override
  String sheetSpeedValue(String speed) {
    return '$speed lines/s';
  }

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get settingsAccentColor => 'Accent color';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentRose => 'Rose';

  @override
  String get settingsAppearanceNote =>
      'Affects lists, editor and settings only; the reader follows its per-script stage palette.';

  @override
  String get readerTapToStart =>
      'Tap to start · mic button starts voice following';

  @override
  String get readerStart => 'Start';

  @override
  String get sheetLineStepFollow => 'Line-by-line follow';

  @override
  String get sheetLineStepHint =>
      'Advance only when the next line is recognized, keeping each line stable; turn off for continuous smooth follow.';

  @override
  String get sheetLatencyCompensation => 'Follow latency compensation';

  @override
  String get sheetLatencyCompensationHint =>
      'Use measured decode and render latency to break lines slightly before the voice; off for a baseline comparison.';

  @override
  String get sheetAsrModel => 'Recognition model';

  @override
  String get sheetAsrModelMixed => 'ZH+EN mixed';

  @override
  String get sheetAsrModelZh14m => 'ZH lightweight';

  @override
  String get sheetAsrModelMixedHint =>
      'Supports mixed Chinese/English; unpacks about 209 MB, applies next time following starts.';

  @override
  String get sheetAsrModelZh14mHint =>
      'Default, Chinese only with a smaller footprint; mixed Chinese/English is not supported out of the box.';

  @override
  String get sheetAsrModelSwitchHint =>
      'Takes effect the next time voice following starts.';

  @override
  String get sheetEndBehavior => 'End of script';

  @override
  String get sheetEndBehaviorStop => 'Stop';

  @override
  String get sheetEndBehaviorLoop => 'Loop';

  @override
  String get readerFinished => 'End of script reached';

  @override
  String get micStatusLoading => 'Loading engine';

  @override
  String get micStatusPaused => 'Paused';

  @override
  String get micStatusListening => 'Listening';

  @override
  String get micStatusSilent => 'No speech detected';

  @override
  String get micStatusCaptureLost => 'Mic interrupted, reconnecting…';

  @override
  String get micStatusEngineStalled => 'Speech engine not responding';

  @override
  String get micStatusGateStalled => 'Audio received, script not matched';

  @override
  String get micStatusLowConfidence => 'Low confidence';

  @override
  String get micStatusBackground => 'Listening in background';

  @override
  String get readerRemoteOff => 'Remote';

  @override
  String get readerRemoteOn => 'Remote on';

  @override
  String get remoteTitle => 'Remote';

  @override
  String get remoteEntryHint =>
      'Connect to Dawan Teleprompter on another device (same Wi-Fi)';

  @override
  String get remoteRemoteHint =>
      'Open “Remote” on the Dawan Teleprompter page, then scan the QR code or paste the pairing string on this device.';

  @override
  String get remotePairingLabel => 'Pairing string';

  @override
  String get remotePairingHint => 'tps://pair?host=...&port=...&token=...';

  @override
  String get remoteInvalidPairing =>
      'Invalid pairing string, please copy it again';

  @override
  String get remoteConnect => 'Connect';

  @override
  String get remoteConnecting => 'Connecting to Dawan Teleprompter…';

  @override
  String get remoteConnected => 'Connected';

  @override
  String get remoteConnectionLost => 'Connection lost, reconnecting…';

  @override
  String get remoteFailed => 'Connection failed';

  @override
  String get remoteReconnect => 'Reconnect';

  @override
  String get remoteDisconnect => 'Disconnect';

  @override
  String get remotePlaying => 'Playing';

  @override
  String get remotePaused => 'Paused';

  @override
  String remoteLineStatus(int line, int total) {
    return 'Line $line of $total';
  }

  @override
  String remoteSpeed(String speed) {
    return '$speed lines/s';
  }

  @override
  String get remoteMirror => 'Mirror';

  @override
  String get remoteLock => 'Lock';

  @override
  String get remoteUnlock => 'Unlock';

  @override
  String get remotePrevLine => 'Previous line';

  @override
  String get remoteNextLine => 'Next line';

  @override
  String get remotePlay => 'Resume';

  @override
  String get remotePause => 'Pause';

  @override
  String get remoteSpeedDown => 'Slower';

  @override
  String get remoteSpeedUp => 'Faster';

  @override
  String get remoteHostTitle => 'Remote prompting';

  @override
  String get remoteHostHint =>
      'Scan the QR code or paste the pairing string in “Settings → Remote” on another device.';

  @override
  String get remoteStop => 'Stop remote';

  @override
  String get remoteClose => 'Close';

  @override
  String get remoteStartFailed =>
      'Cannot start the remote service (port may be in use)';

  @override
  String get remoteScan => 'Scan to pair';

  @override
  String get remoteScanTitle => 'Scan pairing QR code';

  @override
  String get remoteScanHint => 'Point at the QR code on the reader page';

  @override
  String get remoteScanBack => 'Paste pairing code instead';

  @override
  String get remoteScanNotPairing => 'Not a Dawan Teleprompter pairing QR code';

  @override
  String get remoteScanPermissionDenied =>
      'Camera permission denied. Grant it or paste the pairing code.';

  @override
  String get remoteScanFailed =>
      'Camera unavailable. Please paste the pairing code.';

  @override
  String get remoteScanUnsupported =>
      'Camera scanning is not supported on this platform. Please paste the pairing code.';

  @override
  String get readerExternalOff => 'External display';

  @override
  String get readerExternalOn => 'Stop external display';

  @override
  String get externalDisplaySelect => 'Select external display';

  @override
  String get externalDisplayNone =>
      'No external display detected (HDMI/DP or virtual display required)';

  @override
  String get externalDisplayHint =>
      'Note: wireless casting (Cast) is usually a mirror, not a separate screen.';

  @override
  String get externalDisplayFailed => 'Cannot show on the external display';

  @override
  String get externalDisplayStop => 'Stop external display';

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordStop => 'Stop recording';

  @override
  String recordElapsed(String time) {
    return 'Recording $time';
  }

  @override
  String get recordSaved => 'Recording saved';

  @override
  String get recordSaveFailed => 'Failed to save recording';

  @override
  String get recordPermissionDenied =>
      'Microphone permission denied; cannot record';

  @override
  String get recordInProgress => 'Stop recording before starting voice follow';

  @override
  String get recordHistory => 'Recording history';

  @override
  String get recordNone => 'No recordings yet';

  @override
  String get recordReplay => 'Replay';

  @override
  String get recordExport => 'Export';

  @override
  String get recordDelete => 'Delete';

  @override
  String get recordDeleteConfirm =>
      'Delete this recording? The audio file will also be removed.';

  @override
  String get recordDeleteFailed => 'Delete failed';

  @override
  String get recordReplayFailed => 'Cannot play recording';

  @override
  String get recordPlay => 'Play';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordExitReplay => 'Exit replay';

  @override
  String recordExportDone(int count) {
    return 'Exported $count files';
  }

  @override
  String get recordExportFailed => 'Export failed';

  @override
  String recordDuration(String time) {
    return 'Duration $time';
  }

  @override
  String get recordRecordingHint => 'Audio stays on this device';

  @override
  String get settingsSectionDeveloper => 'Experiments (dev)';

  @override
  String get settingsAsrLab => 'Voice lab settings';

  @override
  String get settingsAsrLabHint =>
      'Endpoint and capture parameters; debug builds only';

  @override
  String get asrLabTitle => 'Voice lab settings';

  @override
  String get asrLabWarning =>
      'For development and on-device A/B only. Defaults match the release build; changes apply to this device and take effect after restarting the mic.';

  @override
  String get asrLabEndpointSection => 'Endpointing';

  @override
  String get asrLabRule1 => 'Trailing silence with text (rule1)';

  @override
  String get asrLabRule2 => 'Trailing silence only (rule2)';

  @override
  String get asrLabAudioSection => 'Audio capture';

  @override
  String get asrLabAudioSource => 'Audio source';

  @override
  String get asrLabSourceVoice => 'Voice recognition';

  @override
  String get asrLabSourceMic => 'Microphone';

  @override
  String get asrLabAgc => 'Auto gain (AGC)';

  @override
  String get asrLabNs => 'Noise suppression (NS)';

  @override
  String get asrLabAec => 'Echo cancellation (AEC)';

  @override
  String get asrLabBuffer => 'Chunk buffer';

  @override
  String get asrLabBufferRaw => 'Native';

  @override
  String get asrLabBufferNote =>
      'Larger buffers yield steadier chunks but higher first-word latency; Native keeps plugin defaults.';

  @override
  String get asrLabCurrent => 'Current settings (exported with diagnostics)';

  @override
  String get asrLabRestore => 'Restore defaults';

  @override
  String get asrLabRestored => 'Default lab settings restored';

  @override
  String get asrLabSaved => 'Saved; restart the mic to apply';
}
