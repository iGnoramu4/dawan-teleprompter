// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '大皖提词器';

  @override
  String get appScriptsTitle => '台本';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonAdd => '添加';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonRetry => '重试';

  @override
  String get commonLoading => '读取中…';

  @override
  String get homeSearchHint => '搜索标题或正文';

  @override
  String get homeSearch => '搜索';

  @override
  String get homeSearchClose => '关闭搜索';

  @override
  String get homeSortTooltip => '排序';

  @override
  String get homeSortUpdated => '最近更新';

  @override
  String get homeSortCreated => '最近创建';

  @override
  String get homeSortTitle => '标题';

  @override
  String get homeSortChars => '字数';

  @override
  String get homeSettingsTooltip => '设置';

  @override
  String homeErrorLoad(String error) {
    return '读取台本失败：$error';
  }

  @override
  String get homeViewAll => '全部';

  @override
  String get homeViewFavorite => '收藏';

  @override
  String get homeViewArchived => '归档';

  @override
  String get homeViewTrash => '回收站';

  @override
  String get homeEmptyActiveTitle => '还没有台本';

  @override
  String get homeEmptyActiveHint => '新建一篇，或从粘贴/文件导入';

  @override
  String get homeEmptyFavoriteTitle => '还没有收藏';

  @override
  String get homeEmptyFavoriteHint => '在台本菜单里点收藏';

  @override
  String get homeEmptyArchivedTitle => '没有归档的台本';

  @override
  String get homeEmptyArchivedHint => '归档后的台本会显示在这里';

  @override
  String get homeEmptyTrashTitle => '回收站是空的';

  @override
  String get homeEmptyTrashHint => '删除的台本保留 30 天';

  @override
  String get homeNew => '新建';

  @override
  String get homeCreateBlank => '新建空白台本';

  @override
  String get homeCreateBlankHint => '进入编辑器直接输入';

  @override
  String get homeCreatePaste => '粘贴导入';

  @override
  String get homeCreatePasteHint => '从剪贴板粘贴，保留换行';

  @override
  String get homeCreateFile => '从文件导入';

  @override
  String get homeCreateFileHint =>
      '支持 .txt / .md / .tps / .docx / .pdf，文本自动识别 UTF-8 / GBK';

  @override
  String get homeRenameTitle => '重命名';

  @override
  String get homeTitleLabel => '标题';

  @override
  String get homePurgeTitle => '彻底删除';

  @override
  String homePurgeConfirm(String title) {
    return '「$title」及其标记将被永久删除，无法恢复。';
  }

  @override
  String homeCopied(String title) {
    return '已复制「$title」';
  }

  @override
  String homeMovedToTrash(String title) {
    return '「$title」已移到回收站';
  }

  @override
  String homeRestored(String title) {
    return '已恢复「$title」';
  }

  @override
  String homePurged(String title) {
    return '已彻底删除「$title」';
  }

  @override
  String get homeMore => '更多';

  @override
  String get homeMenuEdit => '编辑';

  @override
  String get homeMenuFavorite => '收藏';

  @override
  String get homeMenuUnfavorite => '取消收藏';

  @override
  String get homeMenuArchive => '归档';

  @override
  String get homeMenuUnarchive => '取消归档';

  @override
  String get homeMenuDuplicate => '复制';

  @override
  String get homeMenuExport => '导出 .tps';

  @override
  String get homeMenuExportAll => '导出全部（.tps）';

  @override
  String get homeExportEmpty => '没有可导出的台本';

  @override
  String homeExportAllDone(int count) {
    return '已导出 $count 篇台本';
  }

  @override
  String homeExportDone(String title) {
    return '已导出「$title」';
  }

  @override
  String get homeExportCanceled => '已取消导出';

  @override
  String get homeImportTpsTitle => '导入 .tps';

  @override
  String homeImportTpsConfirm(int count) {
    return '将导入 $count 篇台本（含标记），继续？';
  }

  @override
  String homeImportTpsDone(int count) {
    return '已导入 $count 篇台本';
  }

  @override
  String get homeImportTpsInvalid => '无法识别的 .tps 文件';

  @override
  String get homeImportUnsupported => '仅支持 .txt / .md / .tps / .docx / .pdf 文件';

  @override
  String get homeImportParseFailed => '没能从该文件提取文字（扫描版 PDF 暂不支持）';

  @override
  String get homeMenuDelete => '删除到回收站';

  @override
  String get homeMenuRestore => '恢复';

  @override
  String get homeMenuPurge => '彻底删除';

  @override
  String get homeClipboardEmpty => '剪贴板为空';

  @override
  String get homeClipboardSource => '剪贴板';

  @override
  String homeMetaChars(int charCount, String updated) {
    return '$charCount 字 · $updated';
  }

  @override
  String homeLastViewed(String time) {
    return '上次 $time';
  }

  @override
  String get homeYesterday => '昨天';

  @override
  String homeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String importPreviewTitle(String source) {
    return '导入预览 · $source';
  }

  @override
  String get importDefaultSource => '导入';

  @override
  String get importTitleLabel => '标题';

  @override
  String get importMergeHardBreaks => '合并段内硬换行';

  @override
  String get importMergeHardBreaksHint => '把 PDF/网页复制导致的一句话折断接回去';

  @override
  String get importStripHeaders => '去除页码/页眉页脚';

  @override
  String get importNormalizeWidth => '全角转半角';

  @override
  String get importStripMarkdown => '剥离 Markdown 标记';

  @override
  String importCleanedStats(int charCount) {
    return '清洗后：$charCount 字';
  }

  @override
  String get importEmptyPreview => '（空）';

  @override
  String get importRawEditable => '原始文本（可编辑）';

  @override
  String get importSaveAndEdit => '保存并编辑';

  @override
  String get importSaveAndPrompt => '保存并提词';

  @override
  String get importNoContent => '没有可保存的内容';

  @override
  String get editorUnnamedScript => '未命名台本';

  @override
  String get editorTitle => '编辑台本';

  @override
  String get editorStatusUnsaved => '未保存';

  @override
  String get editorStatusAutoSave => '自动保存';

  @override
  String get editorStatusSaved => '已保存';

  @override
  String get editorPrompt => '提词';

  @override
  String get editorTitleHint => '台本标题';

  @override
  String editorStatsChars(int chars) {
    return '$chars 字';
  }

  @override
  String get editorAddMarker => '添加标记';

  @override
  String get editorSectionHint => '正文';

  @override
  String get editorMarkNeedText => '先输入正文';

  @override
  String get editorMarkerDialogTitle => '添加标记';

  @override
  String editorMarkerOffset(int offset) {
    return '第 $offset 字';
  }

  @override
  String get editorMarkerLabel => '备注（可选）';

  @override
  String editorMarkerAt(String kind, int offset) {
    return '$kind @$offset';
  }

  @override
  String editorSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get editorMissing => '台本不存在或已被删除';

  @override
  String get markerEmphasis => '重点';

  @override
  String get markerPause => '停顿';

  @override
  String get markerBreath => '换气';

  @override
  String get markerAction => '动作';

  @override
  String get markerTime => '时间码';

  @override
  String get markerCustom => '自定义';

  @override
  String get readerBack => '返回';

  @override
  String get readerPrevSentence => '上一句';

  @override
  String get readerNextSentence => '下一句';

  @override
  String get readerPause => '暂停';

  @override
  String get readerResume => '继续';

  @override
  String get readerVoiceOff => '语音跟随';

  @override
  String get readerVoiceOn => '关闭语音跟随';

  @override
  String get readerReplayTooltip => '回放测试音频（仅开发构建）';

  @override
  String get readerHidePanel => '隐藏功能栏';

  @override
  String get readerShowPanel => '显示功能栏';

  @override
  String get readerRestart => '回到开头';

  @override
  String get readerSettings => '阅读设置';

  @override
  String get readerLock => '锁定（屏蔽手势）';

  @override
  String get readerLockedBadge => '已锁定 · 点击解锁';

  @override
  String get readerOverlay => '悬浮提词';

  @override
  String get overlayOpenTooltip => '悬浮提词（在其他应用上方显示）';

  @override
  String get overlayCloseTooltip => '关闭悬浮提词';

  @override
  String get overlayPermissionTitle => '需要悬浮窗权限';

  @override
  String get overlayPermissionBody => '开启后可在其他应用上方显示稿件。接下来会跳转到系统权限页，授权后返回即可。';

  @override
  String get overlayPermissionAction => '去授权';

  @override
  String get overlayPermissionDenied => '未获得悬浮窗权限，已保留应用内提词';

  @override
  String get overlayNotificationTitle => '提词悬浮窗';

  @override
  String get overlayNotificationDenied => '通知权限未授予：悬浮窗仍可使用，但不会显示前台通知';

  @override
  String get overlayWaiting => '等待提词内容…';

  @override
  String readerProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String readerLineRate(String speed) {
    return '$speed 行/秒';
  }

  @override
  String get readerVoicePreparing => '准备中…';

  @override
  String get readerReplayPreparing => '准备回放…';

  @override
  String get readerSavedAsDefault => '已存为全局默认阅读参数';

  @override
  String readerMicStartFailed(String error) {
    return '启动语音跟随失败：$error';
  }

  @override
  String get readerModelInstallFailed => '离线模型安装失败，点「重试」重新安装；未完成的模型文件已清理';

  @override
  String get readerModelInstallFailedUnclean =>
      '离线模型安装失败，点「重试」重新安装；未能清理未完成的模型文件，请先检查存储空间';

  @override
  String get actionRetry => '重试';

  @override
  String readerReplayStartFailed(String error) {
    return '回放启动失败：$error';
  }

  @override
  String get voiceRequestingMic => '请求麦克风…';

  @override
  String get voiceFollowingMic => '跟读中（麦克风）';

  @override
  String voiceAudioError(String error) {
    return '音频采集失败：$error';
  }

  @override
  String voiceReplayStatus(String seconds) {
    return '回放测试音频（$seconds 秒）';
  }

  @override
  String get voiceReplayDone => '回放结束';

  @override
  String voiceReplayFailed(String error) {
    return '回放失败：$error';
  }

  @override
  String get voiceInstallModel => '安装离线模型…';

  @override
  String voiceInstallModelProgress(int percent, int done, int total) {
    return '安装离线模型… $percent%（$done / $total MB）';
  }

  @override
  String get voiceLoadingRecognizer => '加载识别器…（通常几秒）';

  @override
  String voiceReady(String ms) {
    return '识别就绪（加载 $ms ms）';
  }

  @override
  String voiceRecognitionFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionReading => '阅读';

  @override
  String get settingsBarItems => '功能栏按钮';

  @override
  String get settingsBarItemsHint => '选择提词页功能栏默认显示的按钮；返回、设置、隐藏始终显示。';

  @override
  String settingsBarItemsSummary(String items) {
    return '当前：$items';
  }

  @override
  String get barActionPrev => '上一行';

  @override
  String get barActionNext => '下一行';

  @override
  String get barActionPlayPause => '播放/暂停';

  @override
  String get barActionSpeed => '滚动速度';

  @override
  String get barActionFontSize => '字号';

  @override
  String get barActionMic => '语音跟随';

  @override
  String get barActionRestart => '重新开始';

  @override
  String get barActionOverlay => '悬浮窗';

  @override
  String get barActionRemote => '遥控';

  @override
  String get barActionDisplay => '外接屏';

  @override
  String get barActionRecord => '录制';

  @override
  String get barActionHistory => '录制历史';

  @override
  String get barActionLock => '锁定';

  @override
  String get settingsGlobalDefaults => '全局默认阅读参数';

  @override
  String settingsDefaultsSummary(
      String theme, int fontSize, String lineHeight, String speed) {
    return '$theme · $fontSize px · 行距 $lineHeight× · $speed 行/秒';
  }

  @override
  String get settingsRestoreDefaults => '恢复默认参数';

  @override
  String get settingsRestoreHint => '不影响已按台本记忆的参数';

  @override
  String get settingsDefaultsNote => '新台本或未记忆过的台本使用这里的参数；已调过的台本仍保留自己的参数。';

  @override
  String get settingsSectionBackup => '备份';

  @override
  String get settingsBackupNow => '立即备份';

  @override
  String get settingsAutoBackupHint => '每日首次启动自动备份到应用私有目录，保留最近 7 份';

  @override
  String settingsBackupLatest(String time, String size) {
    return '上次备份：$time · $size';
  }

  @override
  String settingsBackupCount(int count) {
    return '共 $count 份';
  }

  @override
  String get settingsBackupNone => '暂无备份';

  @override
  String get settingsBackupDone => '备份完成';

  @override
  String get settingsBackupEmpty => '没有可备份的台本';

  @override
  String settingsBackupFailed(String error) {
    return '备份失败：$error';
  }

  @override
  String get settingsBackupExport => '导出最近备份';

  @override
  String settingsBackupExportDone(String uri) {
    return '备份已导出：$uri';
  }

  @override
  String get settingsSectionTransfer => '互传';

  @override
  String get settingsLanTransfer => '局域网互传';

  @override
  String get settingsLanTransferHint => '同一 Wi-Fi 下用浏览器下载全部台本或上传 .tps';

  @override
  String get settingsLanTransferTitle => '局域网互传';

  @override
  String get settingsLanTransferStop => '关闭本窗口即停止服务；地址含随机密钥，勿分享给不可信设备。';

  @override
  String settingsLanTransferFailed(String error) {
    return '启动失败：$error';
  }

  @override
  String get lanPageTitle => '大皖提词器 · 局域网互传';

  @override
  String get lanPageHint => '同一 Wi-Fi 下打开本页；关闭手机上的互传窗口后服务停止。';

  @override
  String get lanDownloadAll => '下载全部台本（.tps）';

  @override
  String get lanScriptList => '台本';

  @override
  String get lanNoScripts => '暂无可下载的台本';

  @override
  String get lanImportTitle => '导入台本包';

  @override
  String get lanImportButton => '选择 .tps 并导入';

  @override
  String lanImportDone(int count) {
    return '已导入 $count 篇台本';
  }

  @override
  String get lanImportFailed => '导入失败：文件格式不正确';

  @override
  String get settingsSectionDiagnostics => '诊断';

  @override
  String get settingsExportDiagnostics => '导出诊断包';

  @override
  String get settingsExportContains => '包含运行日志与阅读参数';

  @override
  String get settingsExportNoLogs => '日志未初始化（仅导出参数）';

  @override
  String get settingsExportCanceled => '已取消导出';

  @override
  String settingsExportDone(String uri) {
    return '诊断包已导出：$uri';
  }

  @override
  String settingsExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String settingsRecentLogs(int count) {
    return '最近日志（$count 条）';
  }

  @override
  String get settingsNoLogs => '暂无日志';

  @override
  String get settingsRestored => '已恢复默认阅读参数';

  @override
  String get settingsSavedDefault => '已存为全局默认阅读参数';

  @override
  String get readerThemeDark => '舞台暗';

  @override
  String get readerThemeWhite => '高对比白';

  @override
  String get sheetTitle => '阅读设置';

  @override
  String get sheetSaveAsDefault => '存为全局默认';

  @override
  String get sheetRestoreDefaults => '恢复默认';

  @override
  String get sheetSectionVisual => '视觉';

  @override
  String get sheetFontSize => '字号';

  @override
  String get sheetLineHeight => '行距';

  @override
  String get sheetMarginLeft => '左边距';

  @override
  String get sheetMarginRight => '右边距';

  @override
  String get sheetCharsPerLine => '每行字数（自动）';

  @override
  String get sheetCharsAutoHint => '按屏幕宽度、字号与字距自动计算，随旋转/窗口变化重排';

  @override
  String sheetCharsAutoValue(int count) {
    return '当前约 $count 字，随窗口自动调整';
  }

  @override
  String get sheetSectionMatch => '语音匹配宽松度';

  @override
  String get sheetMatchHint => '环境嘈杂或口播与稿件差异大时放宽；抢行明显时收紧';

  @override
  String get matchVeryStrict => '最谨慎';

  @override
  String get matchVeryStrictHint => '只在整行听清后才推进，几乎不会抢行。';

  @override
  String get matchStrict => '严格';

  @override
  String get matchStrictHint => '宁可少跟一点也不抢行，适合安静环境照稿朗读。';

  @override
  String get matchStandard => '标准';

  @override
  String get matchStandardHint => '默认档位，兼顾跟随速度与稳定。';

  @override
  String get matchLoose => '宽松';

  @override
  String get matchLooseHint => '环境有噪声或常临场发挥时更容易跟住。';

  @override
  String get matchVeryLoose => '最宽松';

  @override
  String get matchVeryLooseHint => '噪声大、自由发挥多时也尽量跟随，偶尔会略快。';

  @override
  String get sheetLetterSpacing => '字距';

  @override
  String get sheetAlignCenter => '居中对齐';

  @override
  String get sheetAlignCenterHint => '左对齐 / 居中';

  @override
  String get sheetSectionMirror => '镜像与分光镜';

  @override
  String get sheetMirrorX => '水平镜像';

  @override
  String get sheetMirrorXHint => '分光镜 / 反射提词器';

  @override
  String get sheetMirrorY => '垂直镜像';

  @override
  String get sheetPrismDx => '分光镜水平校准';

  @override
  String get sheetPrismDy => '分光镜垂直校准';

  @override
  String get sheetSectionScroll => '滚动与跟随';

  @override
  String get sheetSpeed => '匀速速度';

  @override
  String get sheetSpeedReset => '速度归零（1.2 行/秒）';

  @override
  String get sheetReadAhead => '阅读带位置（屏高比例）';

  @override
  String get sheetSmoothness => '平滑度';

  @override
  String get sheetPauseStop => '停顿停住';

  @override
  String get sheetPauseStopHint => '识别停滞时不继续滚动';

  @override
  String get sheetKeepScreenOn => '屏幕常亮';

  @override
  String get sheetKeepScreenOnHint => '阅读期间不熄屏';

  @override
  String get sheetSectionOverlay => '悬浮提词';

  @override
  String get sheetOverlayWidth => '窗口宽度';

  @override
  String sheetOverlayWidthValue(int width) {
    return '$width dp';
  }

  @override
  String get sheetOverlayOpacity => '不透明度';

  @override
  String get sheetOverlayLines => '可见行数';

  @override
  String get sheetOverlayLines3 => '3 行';

  @override
  String get sheetOverlayLines5 => '5 行';

  @override
  String get sheetOverlayHint => '仅影响悬浮窗，不改变主阅读画布；窗口始终自动跟随当前行。';

  @override
  String get sheetFooter => '参数会按台本自动记忆（§4.3 C-06），切稿时恢复。';

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
    return '$count 字';
  }

  @override
  String sheetSpeedValue(String speed) {
    return '$speed 行/秒';
  }

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get accentIndigo => '靛蓝';

  @override
  String get accentTeal => '青绿';

  @override
  String get accentAmber => '琥珀';

  @override
  String get accentRose => '玫红';

  @override
  String get settingsAppearanceNote => '仅影响列表、编辑与设置页；阅读页配色仍由台本预设控制。';

  @override
  String get readerTapToStart => '轻点屏幕开始 · 语音跟随请点麦克风';

  @override
  String get readerStart => '开始';

  @override
  String get sheetLineStepFollow => '逐行跟随';

  @override
  String get sheetLineStepHint => '识别命中下一行后才切行，行内保持稳定；关闭后为连续平滑跟随。';

  @override
  String get sheetLatencyCompensation => '跟随延迟补偿';

  @override
  String get sheetLatencyCompensationHint => '按实测的解码与渲染延迟让换行略早于语音；关闭后为对照基线。';

  @override
  String get sheetAsrModel => '识别模型';

  @override
  String get sheetAsrModelMixed => '中英混合';

  @override
  String get sheetAsrModelZh14m => '中文轻量';

  @override
  String get sheetAsrModelMixedHint => '支持中英混说；解包约 209 MB，切换后下次语音跟随生效。';

  @override
  String get sheetAsrModelZh14mHint => '默认，仅中文、占用更小；开箱不支持中英混说。';

  @override
  String get sheetAsrModelSwitchHint => '切换后于下次开始语音跟随时生效。';

  @override
  String get sheetEndBehavior => '篇尾行为';

  @override
  String get sheetEndBehaviorStop => '停止';

  @override
  String get sheetEndBehaviorLoop => '循环';

  @override
  String get readerFinished => '已到篇尾';

  @override
  String get micStatusLoading => '引擎加载中';

  @override
  String get micStatusPaused => '已暂停';

  @override
  String get micStatusListening => '正在收音';

  @override
  String get micStatusSilent => '未检测到语音';

  @override
  String get micStatusCaptureLost => '麦克风中断，正在重连…';

  @override
  String get micStatusEngineStalled => '识别引擎无响应';

  @override
  String get micStatusGateStalled => '已收音，未匹配稿件';

  @override
  String get micStatusLowConfidence => '低置信';

  @override
  String get micStatusBackground => '后台收音';

  @override
  String get readerRemoteOff => '遥控';

  @override
  String get readerRemoteOn => '遥控已开启';

  @override
  String get remoteTitle => '遥控端';

  @override
  String get remoteEntryHint => '连接另一台设备上的大皖提词器（同一 Wi-Fi）';

  @override
  String get remoteRemoteHint => '在提词页打开「遥控」，用本机扫描二维码或粘贴配对串。';

  @override
  String get remotePairingLabel => '配对串';

  @override
  String get remotePairingHint => 'tps://pair?host=...&port=...&token=...';

  @override
  String get remoteInvalidPairing => '配对串无效，请重新复制';

  @override
  String get remoteConnect => '连接';

  @override
  String get remoteConnecting => '正在连接大皖提词器…';

  @override
  String get remoteConnected => '已连接';

  @override
  String get remoteConnectionLost => '连接已断开，正在自动重连…';

  @override
  String get remoteFailed => '连接失败';

  @override
  String get remoteReconnect => '重新连接';

  @override
  String get remoteDisconnect => '断开';

  @override
  String get remotePlaying => '播放中';

  @override
  String get remotePaused => '已暂停';

  @override
  String remoteLineStatus(int line, int total) {
    return '第 $line / $total 行';
  }

  @override
  String remoteSpeed(String speed) {
    return '$speed 行/秒';
  }

  @override
  String get remoteMirror => '镜像';

  @override
  String get remoteLock => '锁定';

  @override
  String get remoteUnlock => '解锁';

  @override
  String get remotePrevLine => '上一行';

  @override
  String get remoteNextLine => '下一行';

  @override
  String get remotePlay => '继续';

  @override
  String get remotePause => '暂停';

  @override
  String get remoteSpeedDown => '降速';

  @override
  String get remoteSpeedUp => '提速';

  @override
  String get remoteHostTitle => '遥控提词';

  @override
  String get remoteHostHint => '用另一台设备的「设置 → 遥控端」扫描二维码或粘贴配对串';

  @override
  String get remoteStop => '停止遥控';

  @override
  String get remoteClose => '关闭';

  @override
  String get remoteStartFailed => '无法开启遥控服务（端口可能被占用）';

  @override
  String get remoteScan => '扫码配对';

  @override
  String get remoteScanTitle => '扫描配对二维码';

  @override
  String get remoteScanHint => '对准主控端阅读页的二维码';

  @override
  String get remoteScanBack => '改为粘贴配对串';

  @override
  String get remoteScanNotPairing => '不是大皖提词器配对二维码';

  @override
  String get remoteScanPermissionDenied => '相机权限被拒绝，请授权或改为粘贴配对串';

  @override
  String get remoteScanFailed => '相机不可用，请改为粘贴配对串';

  @override
  String get remoteScanUnsupported => '当前平台不支持相机扫码，请粘贴配对串';

  @override
  String get readerExternalOff => '外接显示';

  @override
  String get readerExternalOn => '关闭外接显示';

  @override
  String get externalDisplaySelect => '选择外接显示器';

  @override
  String get externalDisplayNone => '未检测到外接显示器（需 HDMI/DP 或虚拟显示）';

  @override
  String get externalDisplayHint => '提示：无线投屏（Cast）通常是镜像，不是独立副屏。';

  @override
  String get externalDisplayFailed => '无法在外接显示器上显示';

  @override
  String get externalDisplayStop => '停止外接显示';

  @override
  String get recordStart => '开始录制';

  @override
  String get recordStop => '停止录制';

  @override
  String recordElapsed(String time) {
    return '录制中 $time';
  }

  @override
  String get recordSaved => '已保存录音';

  @override
  String get recordSaveFailed => '录音保存失败';

  @override
  String get recordPermissionDenied => '麦克风权限被拒绝，无法录制';

  @override
  String get recordInProgress => '录制中不可开启语音跟随，请先停止录制';

  @override
  String get recordHistory => '录制历史';

  @override
  String get recordNone => '暂无录音';

  @override
  String get recordReplay => '复盘';

  @override
  String get recordExport => '导出';

  @override
  String get recordDelete => '删除';

  @override
  String get recordDeleteConfirm => '删除这条录音？音频文件将一并删除。';

  @override
  String get recordDeleteFailed => '删除失败';

  @override
  String get recordReplayFailed => '无法播放录音';

  @override
  String get recordPlay => '播放';

  @override
  String get recordPause => '暂停';

  @override
  String get recordExitReplay => '退出复盘';

  @override
  String recordExportDone(int count) {
    return '已导出 $count 个文件';
  }

  @override
  String get recordExportFailed => '导出失败';

  @override
  String recordDuration(String time) {
    return '时长 $time';
  }

  @override
  String get recordRecordingHint => '音频仅保存在本机';

  @override
  String get settingsSectionDeveloper => '实验（开发）';

  @override
  String get settingsAsrLab => '语音实验配置';

  @override
  String get settingsAsrLabHint => '端点与音频采集参数，仅调试构建可见';

  @override
  String get asrLabTitle => '语音实验配置';

  @override
  String get asrLabWarning => '仅用于开发与真机 A/B。默认值与正式版一致；修改只影响本机，重新开启麦克风后生效。';

  @override
  String get asrLabEndpointSection => '端点检测';

  @override
  String get asrLabRule1 => '句中断句静音（rule1）';

  @override
  String get asrLabRule2 => '纯静音断句（rule2）';

  @override
  String get asrLabAudioSection => '音频采集';

  @override
  String get asrLabAudioSource => '音频源';

  @override
  String get asrLabSourceVoice => '语音识别';

  @override
  String get asrLabSourceMic => '麦克风';

  @override
  String get asrLabAgc => '自动增益（AGC）';

  @override
  String get asrLabNs => '噪声抑制（NS）';

  @override
  String get asrLabAec => '回声消除（AEC）';

  @override
  String get asrLabBuffer => '分片缓冲';

  @override
  String get asrLabBufferRaw => '原始';

  @override
  String get asrLabBufferNote => '缓冲越大分片越整，但首字延迟越高；「原始」跟随插件默认分片。';

  @override
  String get asrLabCurrent => '当前配置（随诊断包导出）';

  @override
  String get asrLabRestore => '恢复默认';

  @override
  String get asrLabRestored => '已恢复默认实验配置';

  @override
  String get asrLabSaved => '已保存，重新开启麦克风后生效';
}
