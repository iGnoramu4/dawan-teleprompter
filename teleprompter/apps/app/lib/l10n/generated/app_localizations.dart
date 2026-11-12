import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'大皖提词器'**
  String get appTitle;

  /// No description provided for @appScriptsTitle.
  ///
  /// In zh, this message translates to:
  /// **'台本'**
  String get appScriptsTitle;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get commonUndo;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get commonLoading;

  /// No description provided for @homeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标题或正文'**
  String get homeSearchHint;

  /// No description provided for @homeSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get homeSearch;

  /// No description provided for @homeSearchClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get homeSearchClose;

  /// No description provided for @homeSortTooltip.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get homeSortTooltip;

  /// No description provided for @homeSortUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get homeSortUpdated;

  /// No description provided for @homeSortCreated.
  ///
  /// In zh, this message translates to:
  /// **'最近创建'**
  String get homeSortCreated;

  /// No description provided for @homeSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get homeSortTitle;

  /// No description provided for @homeSortChars.
  ///
  /// In zh, this message translates to:
  /// **'字数'**
  String get homeSortChars;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeSettingsTooltip;

  /// No description provided for @homeErrorLoad.
  ///
  /// In zh, this message translates to:
  /// **'读取台本失败：{error}'**
  String homeErrorLoad(String error);

  /// No description provided for @homeViewAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get homeViewAll;

  /// No description provided for @homeViewFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get homeViewFavorite;

  /// No description provided for @homeViewArchived.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get homeViewArchived;

  /// No description provided for @homeViewTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get homeViewTrash;

  /// No description provided for @homeEmptyActiveTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有台本'**
  String get homeEmptyActiveTitle;

  /// No description provided for @homeEmptyActiveHint.
  ///
  /// In zh, this message translates to:
  /// **'新建一篇，或从粘贴/文件导入'**
  String get homeEmptyActiveHint;

  /// No description provided for @homeEmptyFavoriteTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏'**
  String get homeEmptyFavoriteTitle;

  /// No description provided for @homeEmptyFavoriteHint.
  ///
  /// In zh, this message translates to:
  /// **'在台本菜单里点收藏'**
  String get homeEmptyFavoriteHint;

  /// No description provided for @homeEmptyArchivedTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有归档的台本'**
  String get homeEmptyArchivedTitle;

  /// No description provided for @homeEmptyArchivedHint.
  ///
  /// In zh, this message translates to:
  /// **'归档后的台本会显示在这里'**
  String get homeEmptyArchivedHint;

  /// No description provided for @homeEmptyTrashTitle.
  ///
  /// In zh, this message translates to:
  /// **'回收站是空的'**
  String get homeEmptyTrashTitle;

  /// No description provided for @homeEmptyTrashHint.
  ///
  /// In zh, this message translates to:
  /// **'删除的台本保留 30 天'**
  String get homeEmptyTrashHint;

  /// No description provided for @homeNew.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get homeNew;

  /// No description provided for @homeCreateBlank.
  ///
  /// In zh, this message translates to:
  /// **'新建空白台本'**
  String get homeCreateBlank;

  /// No description provided for @homeCreateBlankHint.
  ///
  /// In zh, this message translates to:
  /// **'进入编辑器直接输入'**
  String get homeCreateBlankHint;

  /// No description provided for @homeCreatePaste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴导入'**
  String get homeCreatePaste;

  /// No description provided for @homeCreatePasteHint.
  ///
  /// In zh, this message translates to:
  /// **'从剪贴板粘贴，保留换行'**
  String get homeCreatePasteHint;

  /// No description provided for @homeCreateFile.
  ///
  /// In zh, this message translates to:
  /// **'从文件导入'**
  String get homeCreateFile;

  /// No description provided for @homeCreateFileHint.
  ///
  /// In zh, this message translates to:
  /// **'支持 .txt / .md / .tps / .docx / .pdf，文本自动识别 UTF-8 / GBK'**
  String get homeCreateFileHint;

  /// No description provided for @homeRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get homeRenameTitle;

  /// No description provided for @homeTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get homeTitleLabel;

  /// No description provided for @homePurgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get homePurgeTitle;

  /// No description provided for @homePurgeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」及其标记将被永久删除，无法恢复。'**
  String homePurgeConfirm(String title);

  /// No description provided for @homeCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制「{title}」'**
  String homeCopied(String title);

  /// No description provided for @homeMovedToTrash.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」已移到回收站'**
  String homeMovedToTrash(String title);

  /// No description provided for @homeRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复「{title}」'**
  String homeRestored(String title);

  /// No description provided for @homePurged.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除「{title}」'**
  String homePurged(String title);

  /// No description provided for @homeMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get homeMore;

  /// No description provided for @homeMenuEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get homeMenuEdit;

  /// No description provided for @homeMenuFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get homeMenuFavorite;

  /// No description provided for @homeMenuUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get homeMenuUnfavorite;

  /// No description provided for @homeMenuArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get homeMenuArchive;

  /// No description provided for @homeMenuUnarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get homeMenuUnarchive;

  /// No description provided for @homeMenuDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get homeMenuDuplicate;

  /// No description provided for @homeMenuExport.
  ///
  /// In zh, this message translates to:
  /// **'导出 .tps'**
  String get homeMenuExport;

  /// No description provided for @homeMenuExportAll.
  ///
  /// In zh, this message translates to:
  /// **'导出全部（.tps）'**
  String get homeMenuExportAll;

  /// No description provided for @homeExportEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的台本'**
  String get homeExportEmpty;

  /// No description provided for @homeExportAllDone.
  ///
  /// In zh, this message translates to:
  /// **'已导出 {count} 篇台本'**
  String homeExportAllDone(int count);

  /// No description provided for @homeExportDone.
  ///
  /// In zh, this message translates to:
  /// **'已导出「{title}」'**
  String homeExportDone(String title);

  /// No description provided for @homeExportCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消导出'**
  String get homeExportCanceled;

  /// No description provided for @homeImportTpsTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入 .tps'**
  String get homeImportTpsTitle;

  /// No description provided for @homeImportTpsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将导入 {count} 篇台本（含标记），继续？'**
  String homeImportTpsConfirm(int count);

  /// No description provided for @homeImportTpsDone.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 篇台本'**
  String homeImportTpsDone(int count);

  /// No description provided for @homeImportTpsInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无法识别的 .tps 文件'**
  String get homeImportTpsInvalid;

  /// No description provided for @homeImportUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'仅支持 .txt / .md / .tps / .docx / .pdf 文件'**
  String get homeImportUnsupported;

  /// No description provided for @homeImportParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能从该文件提取文字（扫描版 PDF 暂不支持）'**
  String get homeImportParseFailed;

  /// No description provided for @homeMenuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除到回收站'**
  String get homeMenuDelete;

  /// No description provided for @homeMenuRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get homeMenuRestore;

  /// No description provided for @homeMenuPurge.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get homeMenuPurge;

  /// No description provided for @homeClipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板为空'**
  String get homeClipboardEmpty;

  /// No description provided for @homeClipboardSource.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板'**
  String get homeClipboardSource;

  /// No description provided for @homeMetaChars.
  ///
  /// In zh, this message translates to:
  /// **'{charCount} 字 · {updated}'**
  String homeMetaChars(int charCount, String updated);

  /// No description provided for @homeLastViewed.
  ///
  /// In zh, this message translates to:
  /// **'上次 {time}'**
  String homeLastViewed(String time);

  /// No description provided for @homeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get homeYesterday;

  /// No description provided for @homeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String homeDaysAgo(int count);

  /// No description provided for @importPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入预览 · {source}'**
  String importPreviewTitle(String source);

  /// No description provided for @importDefaultSource.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importDefaultSource;

  /// No description provided for @importTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get importTitleLabel;

  /// No description provided for @importMergeHardBreaks.
  ///
  /// In zh, this message translates to:
  /// **'合并段内硬换行'**
  String get importMergeHardBreaks;

  /// No description provided for @importMergeHardBreaksHint.
  ///
  /// In zh, this message translates to:
  /// **'把 PDF/网页复制导致的一句话折断接回去'**
  String get importMergeHardBreaksHint;

  /// No description provided for @importStripHeaders.
  ///
  /// In zh, this message translates to:
  /// **'去除页码/页眉页脚'**
  String get importStripHeaders;

  /// No description provided for @importNormalizeWidth.
  ///
  /// In zh, this message translates to:
  /// **'全角转半角'**
  String get importNormalizeWidth;

  /// No description provided for @importStripMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'剥离 Markdown 标记'**
  String get importStripMarkdown;

  /// No description provided for @importCleanedStats.
  ///
  /// In zh, this message translates to:
  /// **'清洗后：{charCount} 字'**
  String importCleanedStats(int charCount);

  /// No description provided for @importEmptyPreview.
  ///
  /// In zh, this message translates to:
  /// **'（空）'**
  String get importEmptyPreview;

  /// No description provided for @importRawEditable.
  ///
  /// In zh, this message translates to:
  /// **'原始文本（可编辑）'**
  String get importRawEditable;

  /// No description provided for @importSaveAndEdit.
  ///
  /// In zh, this message translates to:
  /// **'保存并编辑'**
  String get importSaveAndEdit;

  /// No description provided for @importSaveAndPrompt.
  ///
  /// In zh, this message translates to:
  /// **'保存并提词'**
  String get importSaveAndPrompt;

  /// No description provided for @importNoContent.
  ///
  /// In zh, this message translates to:
  /// **'没有可保存的内容'**
  String get importNoContent;

  /// No description provided for @editorUnnamedScript.
  ///
  /// In zh, this message translates to:
  /// **'未命名台本'**
  String get editorUnnamedScript;

  /// No description provided for @editorTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑台本'**
  String get editorTitle;

  /// No description provided for @editorStatusUnsaved.
  ///
  /// In zh, this message translates to:
  /// **'未保存'**
  String get editorStatusUnsaved;

  /// No description provided for @editorStatusAutoSave.
  ///
  /// In zh, this message translates to:
  /// **'自动保存'**
  String get editorStatusAutoSave;

  /// No description provided for @editorStatusSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get editorStatusSaved;

  /// No description provided for @editorPrompt.
  ///
  /// In zh, this message translates to:
  /// **'提词'**
  String get editorPrompt;

  /// No description provided for @editorTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'台本标题'**
  String get editorTitleHint;

  /// No description provided for @editorStatsChars.
  ///
  /// In zh, this message translates to:
  /// **'{chars} 字'**
  String editorStatsChars(int chars);

  /// No description provided for @editorAddMarker.
  ///
  /// In zh, this message translates to:
  /// **'添加标记'**
  String get editorAddMarker;

  /// No description provided for @editorSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get editorSectionHint;

  /// No description provided for @editorMarkNeedText.
  ///
  /// In zh, this message translates to:
  /// **'先输入正文'**
  String get editorMarkNeedText;

  /// No description provided for @editorMarkerDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加标记'**
  String get editorMarkerDialogTitle;

  /// No description provided for @editorMarkerOffset.
  ///
  /// In zh, this message translates to:
  /// **'第 {offset} 字'**
  String editorMarkerOffset(int offset);

  /// No description provided for @editorMarkerLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注（可选）'**
  String get editorMarkerLabel;

  /// No description provided for @editorMarkerAt.
  ///
  /// In zh, this message translates to:
  /// **'{kind} @{offset}'**
  String editorMarkerAt(String kind, int offset);

  /// No description provided for @editorSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String editorSaveFailed(String error);

  /// No description provided for @editorMissing.
  ///
  /// In zh, this message translates to:
  /// **'台本不存在或已被删除'**
  String get editorMissing;

  /// No description provided for @markerEmphasis.
  ///
  /// In zh, this message translates to:
  /// **'重点'**
  String get markerEmphasis;

  /// No description provided for @markerPause.
  ///
  /// In zh, this message translates to:
  /// **'停顿'**
  String get markerPause;

  /// No description provided for @markerBreath.
  ///
  /// In zh, this message translates to:
  /// **'换气'**
  String get markerBreath;

  /// No description provided for @markerAction.
  ///
  /// In zh, this message translates to:
  /// **'动作'**
  String get markerAction;

  /// No description provided for @markerTime.
  ///
  /// In zh, this message translates to:
  /// **'时间码'**
  String get markerTime;

  /// No description provided for @markerCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get markerCustom;

  /// No description provided for @readerBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get readerBack;

  /// No description provided for @readerPrevSentence.
  ///
  /// In zh, this message translates to:
  /// **'上一句'**
  String get readerPrevSentence;

  /// No description provided for @readerNextSentence.
  ///
  /// In zh, this message translates to:
  /// **'下一句'**
  String get readerNextSentence;

  /// No description provided for @readerPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get readerPause;

  /// No description provided for @readerResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get readerResume;

  /// No description provided for @readerVoiceOff.
  ///
  /// In zh, this message translates to:
  /// **'语音跟随'**
  String get readerVoiceOff;

  /// No description provided for @readerVoiceOn.
  ///
  /// In zh, this message translates to:
  /// **'关闭语音跟随'**
  String get readerVoiceOn;

  /// No description provided for @readerReplayTooltip.
  ///
  /// In zh, this message translates to:
  /// **'回放测试音频（仅开发构建）'**
  String get readerReplayTooltip;

  /// No description provided for @readerHidePanel.
  ///
  /// In zh, this message translates to:
  /// **'隐藏功能栏'**
  String get readerHidePanel;

  /// No description provided for @readerShowPanel.
  ///
  /// In zh, this message translates to:
  /// **'显示功能栏'**
  String get readerShowPanel;

  /// No description provided for @readerRestart.
  ///
  /// In zh, this message translates to:
  /// **'回到开头'**
  String get readerRestart;

  /// No description provided for @readerSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readerSettings;

  /// No description provided for @readerLock.
  ///
  /// In zh, this message translates to:
  /// **'锁定（屏蔽手势）'**
  String get readerLock;

  /// No description provided for @readerLockedBadge.
  ///
  /// In zh, this message translates to:
  /// **'已锁定 · 点击解锁'**
  String get readerLockedBadge;

  /// No description provided for @readerOverlay.
  ///
  /// In zh, this message translates to:
  /// **'悬浮提词'**
  String get readerOverlay;

  /// No description provided for @overlayOpenTooltip.
  ///
  /// In zh, this message translates to:
  /// **'悬浮提词（在其他应用上方显示）'**
  String get overlayOpenTooltip;

  /// No description provided for @overlayCloseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关闭悬浮提词'**
  String get overlayCloseTooltip;

  /// No description provided for @overlayPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要悬浮窗权限'**
  String get overlayPermissionTitle;

  /// No description provided for @overlayPermissionBody.
  ///
  /// In zh, this message translates to:
  /// **'开启后可在其他应用上方显示稿件。接下来会跳转到系统权限页，授权后返回即可。'**
  String get overlayPermissionBody;

  /// No description provided for @overlayPermissionAction.
  ///
  /// In zh, this message translates to:
  /// **'去授权'**
  String get overlayPermissionAction;

  /// No description provided for @overlayPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未获得悬浮窗权限，已保留应用内提词'**
  String get overlayPermissionDenied;

  /// No description provided for @overlayNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'提词悬浮窗'**
  String get overlayNotificationTitle;

  /// No description provided for @overlayNotificationDenied.
  ///
  /// In zh, this message translates to:
  /// **'通知权限未授予：悬浮窗仍可使用，但不会显示前台通知'**
  String get overlayNotificationDenied;

  /// No description provided for @overlayWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待提词内容…'**
  String get overlayWaiting;

  /// No description provided for @readerProgress.
  ///
  /// In zh, this message translates to:
  /// **'{current} / {total}'**
  String readerProgress(int current, int total);

  /// No description provided for @readerLineRate.
  ///
  /// In zh, this message translates to:
  /// **'{speed} 行/秒'**
  String readerLineRate(String speed);

  /// No description provided for @readerVoicePreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中…'**
  String get readerVoicePreparing;

  /// No description provided for @readerReplayPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备回放…'**
  String get readerReplayPreparing;

  /// No description provided for @readerSavedAsDefault.
  ///
  /// In zh, this message translates to:
  /// **'已存为全局默认阅读参数'**
  String get readerSavedAsDefault;

  /// No description provided for @readerMicStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动语音跟随失败：{error}'**
  String readerMicStartFailed(String error);

  /// No description provided for @readerModelInstallFailed.
  ///
  /// In zh, this message translates to:
  /// **'离线模型安装失败，点「重试」重新安装；未完成的模型文件已清理'**
  String get readerModelInstallFailed;

  /// No description provided for @readerModelInstallFailedUnclean.
  ///
  /// In zh, this message translates to:
  /// **'离线模型安装失败，点「重试」重新安装；未能清理未完成的模型文件，请先检查存储空间'**
  String get readerModelInstallFailedUnclean;

  /// No description provided for @actionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get actionRetry;

  /// No description provided for @readerReplayStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'回放启动失败：{error}'**
  String readerReplayStartFailed(String error);

  /// No description provided for @voiceRequestingMic.
  ///
  /// In zh, this message translates to:
  /// **'请求麦克风…'**
  String get voiceRequestingMic;

  /// No description provided for @voiceFollowingMic.
  ///
  /// In zh, this message translates to:
  /// **'跟读中（麦克风）'**
  String get voiceFollowingMic;

  /// No description provided for @voiceAudioError.
  ///
  /// In zh, this message translates to:
  /// **'音频采集失败：{error}'**
  String voiceAudioError(String error);

  /// No description provided for @voiceReplayStatus.
  ///
  /// In zh, this message translates to:
  /// **'回放测试音频（{seconds} 秒）'**
  String voiceReplayStatus(String seconds);

  /// No description provided for @voiceReplayDone.
  ///
  /// In zh, this message translates to:
  /// **'回放结束'**
  String get voiceReplayDone;

  /// No description provided for @voiceReplayFailed.
  ///
  /// In zh, this message translates to:
  /// **'回放失败：{error}'**
  String voiceReplayFailed(String error);

  /// No description provided for @voiceInstallModel.
  ///
  /// In zh, this message translates to:
  /// **'安装离线模型…'**
  String get voiceInstallModel;

  /// No description provided for @voiceInstallModelProgress.
  ///
  /// In zh, this message translates to:
  /// **'安装离线模型… {percent}%（{done} / {total} MB）'**
  String voiceInstallModelProgress(int percent, int done, int total);

  /// No description provided for @voiceLoadingRecognizer.
  ///
  /// In zh, this message translates to:
  /// **'加载识别器…（通常几秒）'**
  String get voiceLoadingRecognizer;

  /// No description provided for @voiceReady.
  ///
  /// In zh, this message translates to:
  /// **'识别就绪（加载 {ms} ms）'**
  String voiceReady(String ms);

  /// No description provided for @voiceRecognitionFailed.
  ///
  /// In zh, this message translates to:
  /// **'识别失败：{error}'**
  String voiceRecognitionFailed(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSectionReading.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get settingsSectionReading;

  /// No description provided for @settingsBarItems.
  ///
  /// In zh, this message translates to:
  /// **'功能栏按钮'**
  String get settingsBarItems;

  /// No description provided for @settingsBarItemsHint.
  ///
  /// In zh, this message translates to:
  /// **'选择提词页功能栏默认显示的按钮；返回、设置、隐藏始终显示。'**
  String get settingsBarItemsHint;

  /// No description provided for @settingsBarItemsSummary.
  ///
  /// In zh, this message translates to:
  /// **'当前：{items}'**
  String settingsBarItemsSummary(String items);

  /// No description provided for @barActionPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一行'**
  String get barActionPrev;

  /// No description provided for @barActionNext.
  ///
  /// In zh, this message translates to:
  /// **'下一行'**
  String get barActionNext;

  /// No description provided for @barActionPlayPause.
  ///
  /// In zh, this message translates to:
  /// **'播放/暂停'**
  String get barActionPlayPause;

  /// No description provided for @barActionSpeed.
  ///
  /// In zh, this message translates to:
  /// **'滚动速度'**
  String get barActionSpeed;

  /// No description provided for @barActionFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get barActionFontSize;

  /// No description provided for @barActionMic.
  ///
  /// In zh, this message translates to:
  /// **'语音跟随'**
  String get barActionMic;

  /// No description provided for @barActionRestart.
  ///
  /// In zh, this message translates to:
  /// **'重新开始'**
  String get barActionRestart;

  /// No description provided for @barActionOverlay.
  ///
  /// In zh, this message translates to:
  /// **'悬浮窗'**
  String get barActionOverlay;

  /// No description provided for @barActionRemote.
  ///
  /// In zh, this message translates to:
  /// **'遥控'**
  String get barActionRemote;

  /// No description provided for @barActionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'外接屏'**
  String get barActionDisplay;

  /// No description provided for @barActionRecord.
  ///
  /// In zh, this message translates to:
  /// **'录制'**
  String get barActionRecord;

  /// No description provided for @barActionHistory.
  ///
  /// In zh, this message translates to:
  /// **'录制历史'**
  String get barActionHistory;

  /// No description provided for @barActionLock.
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get barActionLock;

  /// No description provided for @settingsGlobalDefaults.
  ///
  /// In zh, this message translates to:
  /// **'全局默认阅读参数'**
  String get settingsGlobalDefaults;

  /// No description provided for @settingsDefaultsSummary.
  ///
  /// In zh, this message translates to:
  /// **'{theme} · {fontSize} px · 行距 {lineHeight}× · {speed} 行/秒'**
  String settingsDefaultsSummary(
      String theme, int fontSize, String lineHeight, String speed);

  /// No description provided for @settingsRestoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认参数'**
  String get settingsRestoreDefaults;

  /// No description provided for @settingsRestoreHint.
  ///
  /// In zh, this message translates to:
  /// **'不影响已按台本记忆的参数'**
  String get settingsRestoreHint;

  /// No description provided for @settingsDefaultsNote.
  ///
  /// In zh, this message translates to:
  /// **'新台本或未记忆过的台本使用这里的参数；已调过的台本仍保留自己的参数。'**
  String get settingsDefaultsNote;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get settingsSectionBackup;

  /// No description provided for @settingsBackupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get settingsBackupNow;

  /// No description provided for @settingsAutoBackupHint.
  ///
  /// In zh, this message translates to:
  /// **'每日首次启动自动备份到应用私有目录，保留最近 7 份'**
  String get settingsAutoBackupHint;

  /// No description provided for @settingsBackupLatest.
  ///
  /// In zh, this message translates to:
  /// **'上次备份：{time} · {size}'**
  String settingsBackupLatest(String time, String size);

  /// No description provided for @settingsBackupCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 份'**
  String settingsBackupCount(int count);

  /// No description provided for @settingsBackupNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无备份'**
  String get settingsBackupNone;

  /// No description provided for @settingsBackupDone.
  ///
  /// In zh, this message translates to:
  /// **'备份完成'**
  String get settingsBackupDone;

  /// No description provided for @settingsBackupEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可备份的台本'**
  String get settingsBackupEmpty;

  /// No description provided for @settingsBackupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败：{error}'**
  String settingsBackupFailed(String error);

  /// No description provided for @settingsBackupExport.
  ///
  /// In zh, this message translates to:
  /// **'导出最近备份'**
  String get settingsBackupExport;

  /// No description provided for @settingsBackupExportDone.
  ///
  /// In zh, this message translates to:
  /// **'备份已导出：{uri}'**
  String settingsBackupExportDone(String uri);

  /// No description provided for @settingsSectionTransfer.
  ///
  /// In zh, this message translates to:
  /// **'互传'**
  String get settingsSectionTransfer;

  /// No description provided for @settingsLanTransfer.
  ///
  /// In zh, this message translates to:
  /// **'局域网互传'**
  String get settingsLanTransfer;

  /// No description provided for @settingsLanTransferHint.
  ///
  /// In zh, this message translates to:
  /// **'同一 Wi-Fi 下用浏览器下载全部台本或上传 .tps'**
  String get settingsLanTransferHint;

  /// No description provided for @settingsLanTransferTitle.
  ///
  /// In zh, this message translates to:
  /// **'局域网互传'**
  String get settingsLanTransferTitle;

  /// No description provided for @settingsLanTransferStop.
  ///
  /// In zh, this message translates to:
  /// **'关闭本窗口即停止服务；地址含随机密钥，勿分享给不可信设备。'**
  String get settingsLanTransferStop;

  /// No description provided for @settingsLanTransferFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动失败：{error}'**
  String settingsLanTransferFailed(String error);

  /// No description provided for @lanPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'大皖提词器 · 局域网互传'**
  String get lanPageTitle;

  /// No description provided for @lanPageHint.
  ///
  /// In zh, this message translates to:
  /// **'同一 Wi-Fi 下打开本页；关闭手机上的互传窗口后服务停止。'**
  String get lanPageHint;

  /// No description provided for @lanDownloadAll.
  ///
  /// In zh, this message translates to:
  /// **'下载全部台本（.tps）'**
  String get lanDownloadAll;

  /// No description provided for @lanScriptList.
  ///
  /// In zh, this message translates to:
  /// **'台本'**
  String get lanScriptList;

  /// No description provided for @lanNoScripts.
  ///
  /// In zh, this message translates to:
  /// **'暂无可下载的台本'**
  String get lanNoScripts;

  /// No description provided for @lanImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入台本包'**
  String get lanImportTitle;

  /// No description provided for @lanImportButton.
  ///
  /// In zh, this message translates to:
  /// **'选择 .tps 并导入'**
  String get lanImportButton;

  /// No description provided for @lanImportDone.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 篇台本'**
  String lanImportDone(int count);

  /// No description provided for @lanImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：文件格式不正确'**
  String get lanImportFailed;

  /// No description provided for @settingsSectionDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'诊断'**
  String get settingsSectionDiagnostics;

  /// No description provided for @settingsExportDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'导出诊断包'**
  String get settingsExportDiagnostics;

  /// No description provided for @settingsExportContains.
  ///
  /// In zh, this message translates to:
  /// **'包含运行日志与阅读参数'**
  String get settingsExportContains;

  /// No description provided for @settingsExportNoLogs.
  ///
  /// In zh, this message translates to:
  /// **'日志未初始化（仅导出参数）'**
  String get settingsExportNoLogs;

  /// No description provided for @settingsExportCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消导出'**
  String get settingsExportCanceled;

  /// No description provided for @settingsExportDone.
  ///
  /// In zh, this message translates to:
  /// **'诊断包已导出：{uri}'**
  String settingsExportDone(String uri);

  /// No description provided for @settingsExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsRecentLogs.
  ///
  /// In zh, this message translates to:
  /// **'最近日志（{count} 条）'**
  String settingsRecentLogs(int count);

  /// No description provided for @settingsNoLogs.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get settingsNoLogs;

  /// No description provided for @settingsRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认阅读参数'**
  String get settingsRestored;

  /// No description provided for @settingsSavedDefault.
  ///
  /// In zh, this message translates to:
  /// **'已存为全局默认阅读参数'**
  String get settingsSavedDefault;

  /// No description provided for @readerThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'舞台暗'**
  String get readerThemeDark;

  /// No description provided for @readerThemeWhite.
  ///
  /// In zh, this message translates to:
  /// **'高对比白'**
  String get readerThemeWhite;

  /// No description provided for @sheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get sheetTitle;

  /// No description provided for @sheetSaveAsDefault.
  ///
  /// In zh, this message translates to:
  /// **'存为全局默认'**
  String get sheetSaveAsDefault;

  /// No description provided for @sheetRestoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get sheetRestoreDefaults;

  /// No description provided for @sheetSectionVisual.
  ///
  /// In zh, this message translates to:
  /// **'视觉'**
  String get sheetSectionVisual;

  /// No description provided for @sheetFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get sheetFontSize;

  /// No description provided for @sheetLineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get sheetLineHeight;

  /// No description provided for @sheetMarginLeft.
  ///
  /// In zh, this message translates to:
  /// **'左边距'**
  String get sheetMarginLeft;

  /// No description provided for @sheetMarginRight.
  ///
  /// In zh, this message translates to:
  /// **'右边距'**
  String get sheetMarginRight;

  /// No description provided for @sheetCharsPerLine.
  ///
  /// In zh, this message translates to:
  /// **'每行字数（自动）'**
  String get sheetCharsPerLine;

  /// No description provided for @sheetCharsAutoHint.
  ///
  /// In zh, this message translates to:
  /// **'按屏幕宽度、字号与字距自动计算，随旋转/窗口变化重排'**
  String get sheetCharsAutoHint;

  /// No description provided for @sheetCharsAutoValue.
  ///
  /// In zh, this message translates to:
  /// **'当前约 {count} 字，随窗口自动调整'**
  String sheetCharsAutoValue(int count);

  /// No description provided for @sheetSectionMatch.
  ///
  /// In zh, this message translates to:
  /// **'语音匹配宽松度'**
  String get sheetSectionMatch;

  /// No description provided for @sheetMatchHint.
  ///
  /// In zh, this message translates to:
  /// **'环境嘈杂或口播与稿件差异大时放宽；抢行明显时收紧'**
  String get sheetMatchHint;

  /// No description provided for @matchVeryStrict.
  ///
  /// In zh, this message translates to:
  /// **'最谨慎'**
  String get matchVeryStrict;

  /// No description provided for @matchVeryStrictHint.
  ///
  /// In zh, this message translates to:
  /// **'只在整行听清后才推进，几乎不会抢行。'**
  String get matchVeryStrictHint;

  /// No description provided for @matchStrict.
  ///
  /// In zh, this message translates to:
  /// **'严格'**
  String get matchStrict;

  /// No description provided for @matchStrictHint.
  ///
  /// In zh, this message translates to:
  /// **'宁可少跟一点也不抢行，适合安静环境照稿朗读。'**
  String get matchStrictHint;

  /// No description provided for @matchStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get matchStandard;

  /// No description provided for @matchStandardHint.
  ///
  /// In zh, this message translates to:
  /// **'默认档位，兼顾跟随速度与稳定。'**
  String get matchStandardHint;

  /// No description provided for @matchLoose.
  ///
  /// In zh, this message translates to:
  /// **'宽松'**
  String get matchLoose;

  /// No description provided for @matchLooseHint.
  ///
  /// In zh, this message translates to:
  /// **'环境有噪声或常临场发挥时更容易跟住。'**
  String get matchLooseHint;

  /// No description provided for @matchVeryLoose.
  ///
  /// In zh, this message translates to:
  /// **'最宽松'**
  String get matchVeryLoose;

  /// No description provided for @matchVeryLooseHint.
  ///
  /// In zh, this message translates to:
  /// **'噪声大、自由发挥多时也尽量跟随，偶尔会略快。'**
  String get matchVeryLooseHint;

  /// No description provided for @sheetLetterSpacing.
  ///
  /// In zh, this message translates to:
  /// **'字距'**
  String get sheetLetterSpacing;

  /// No description provided for @sheetAlignCenter.
  ///
  /// In zh, this message translates to:
  /// **'居中对齐'**
  String get sheetAlignCenter;

  /// No description provided for @sheetAlignCenterHint.
  ///
  /// In zh, this message translates to:
  /// **'左对齐 / 居中'**
  String get sheetAlignCenterHint;

  /// No description provided for @sheetSectionMirror.
  ///
  /// In zh, this message translates to:
  /// **'镜像与分光镜'**
  String get sheetSectionMirror;

  /// No description provided for @sheetMirrorX.
  ///
  /// In zh, this message translates to:
  /// **'水平镜像'**
  String get sheetMirrorX;

  /// No description provided for @sheetMirrorXHint.
  ///
  /// In zh, this message translates to:
  /// **'分光镜 / 反射提词器'**
  String get sheetMirrorXHint;

  /// No description provided for @sheetMirrorY.
  ///
  /// In zh, this message translates to:
  /// **'垂直镜像'**
  String get sheetMirrorY;

  /// No description provided for @sheetPrismDx.
  ///
  /// In zh, this message translates to:
  /// **'分光镜水平校准'**
  String get sheetPrismDx;

  /// No description provided for @sheetPrismDy.
  ///
  /// In zh, this message translates to:
  /// **'分光镜垂直校准'**
  String get sheetPrismDy;

  /// No description provided for @sheetSectionScroll.
  ///
  /// In zh, this message translates to:
  /// **'滚动与跟随'**
  String get sheetSectionScroll;

  /// No description provided for @sheetSpeed.
  ///
  /// In zh, this message translates to:
  /// **'匀速速度'**
  String get sheetSpeed;

  /// No description provided for @sheetSpeedReset.
  ///
  /// In zh, this message translates to:
  /// **'速度归零（1.2 行/秒）'**
  String get sheetSpeedReset;

  /// No description provided for @sheetReadAhead.
  ///
  /// In zh, this message translates to:
  /// **'阅读带位置（屏高比例）'**
  String get sheetReadAhead;

  /// No description provided for @sheetSmoothness.
  ///
  /// In zh, this message translates to:
  /// **'平滑度'**
  String get sheetSmoothness;

  /// No description provided for @sheetPauseStop.
  ///
  /// In zh, this message translates to:
  /// **'停顿停住'**
  String get sheetPauseStop;

  /// No description provided for @sheetPauseStopHint.
  ///
  /// In zh, this message translates to:
  /// **'识别停滞时不继续滚动'**
  String get sheetPauseStopHint;

  /// No description provided for @sheetKeepScreenOn.
  ///
  /// In zh, this message translates to:
  /// **'屏幕常亮'**
  String get sheetKeepScreenOn;

  /// No description provided for @sheetKeepScreenOnHint.
  ///
  /// In zh, this message translates to:
  /// **'阅读期间不熄屏'**
  String get sheetKeepScreenOnHint;

  /// No description provided for @sheetSectionOverlay.
  ///
  /// In zh, this message translates to:
  /// **'悬浮提词'**
  String get sheetSectionOverlay;

  /// No description provided for @sheetOverlayWidth.
  ///
  /// In zh, this message translates to:
  /// **'窗口宽度'**
  String get sheetOverlayWidth;

  /// No description provided for @sheetOverlayWidthValue.
  ///
  /// In zh, this message translates to:
  /// **'{width} dp'**
  String sheetOverlayWidthValue(int width);

  /// No description provided for @sheetOverlayOpacity.
  ///
  /// In zh, this message translates to:
  /// **'不透明度'**
  String get sheetOverlayOpacity;

  /// No description provided for @sheetOverlayLines.
  ///
  /// In zh, this message translates to:
  /// **'可见行数'**
  String get sheetOverlayLines;

  /// No description provided for @sheetOverlayLines3.
  ///
  /// In zh, this message translates to:
  /// **'3 行'**
  String get sheetOverlayLines3;

  /// No description provided for @sheetOverlayLines5.
  ///
  /// In zh, this message translates to:
  /// **'5 行'**
  String get sheetOverlayLines5;

  /// No description provided for @sheetOverlayHint.
  ///
  /// In zh, this message translates to:
  /// **'仅影响悬浮窗，不改变主阅读画布；窗口始终自动跟随当前行。'**
  String get sheetOverlayHint;

  /// No description provided for @sheetFooter.
  ///
  /// In zh, this message translates to:
  /// **'参数会按台本自动记忆（§4.3 C-06），切稿时恢复。'**
  String get sheetFooter;

  /// No description provided for @sheetFontSizeValue.
  ///
  /// In zh, this message translates to:
  /// **'{size} px'**
  String sheetFontSizeValue(int size);

  /// No description provided for @sheetLineHeightValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}×'**
  String sheetLineHeightValue(String value);

  /// No description provided for @sheetPercentValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent}%'**
  String sheetPercentValue(int percent);

  /// No description provided for @sheetCharsValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String sheetCharsValue(int count);

  /// No description provided for @sheetSpeedValue.
  ///
  /// In zh, this message translates to:
  /// **'{speed} 行/秒'**
  String sheetSpeedValue(String speed);

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @settingsAccentColor.
  ///
  /// In zh, this message translates to:
  /// **'强调色'**
  String get settingsAccentColor;

  /// No description provided for @accentIndigo.
  ///
  /// In zh, this message translates to:
  /// **'靛蓝'**
  String get accentIndigo;

  /// No description provided for @accentTeal.
  ///
  /// In zh, this message translates to:
  /// **'青绿'**
  String get accentTeal;

  /// No description provided for @accentAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀'**
  String get accentAmber;

  /// No description provided for @accentRose.
  ///
  /// In zh, this message translates to:
  /// **'玫红'**
  String get accentRose;

  /// No description provided for @settingsAppearanceNote.
  ///
  /// In zh, this message translates to:
  /// **'仅影响列表、编辑与设置页；阅读页配色仍由台本预设控制。'**
  String get settingsAppearanceNote;

  /// No description provided for @readerTapToStart.
  ///
  /// In zh, this message translates to:
  /// **'轻点屏幕开始 · 语音跟随请点麦克风'**
  String get readerTapToStart;

  /// No description provided for @readerStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get readerStart;

  /// No description provided for @sheetLineStepFollow.
  ///
  /// In zh, this message translates to:
  /// **'逐行跟随'**
  String get sheetLineStepFollow;

  /// No description provided for @sheetLineStepHint.
  ///
  /// In zh, this message translates to:
  /// **'识别命中下一行后才切行，行内保持稳定；关闭后为连续平滑跟随。'**
  String get sheetLineStepHint;

  /// No description provided for @sheetLatencyCompensation.
  ///
  /// In zh, this message translates to:
  /// **'跟随延迟补偿'**
  String get sheetLatencyCompensation;

  /// No description provided for @sheetLatencyCompensationHint.
  ///
  /// In zh, this message translates to:
  /// **'按实测的解码与渲染延迟让换行略早于语音；关闭后为对照基线。'**
  String get sheetLatencyCompensationHint;

  /// No description provided for @sheetAsrModel.
  ///
  /// In zh, this message translates to:
  /// **'识别模型'**
  String get sheetAsrModel;

  /// No description provided for @sheetAsrModelMixed.
  ///
  /// In zh, this message translates to:
  /// **'中英混合'**
  String get sheetAsrModelMixed;

  /// No description provided for @sheetAsrModelZh14m.
  ///
  /// In zh, this message translates to:
  /// **'中文轻量'**
  String get sheetAsrModelZh14m;

  /// No description provided for @sheetAsrModelMixedHint.
  ///
  /// In zh, this message translates to:
  /// **'支持中英混说；解包约 209 MB，切换后下次语音跟随生效。'**
  String get sheetAsrModelMixedHint;

  /// No description provided for @sheetAsrModelZh14mHint.
  ///
  /// In zh, this message translates to:
  /// **'默认，仅中文、占用更小；开箱不支持中英混说。'**
  String get sheetAsrModelZh14mHint;

  /// No description provided for @sheetAsrModelSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'切换后于下次开始语音跟随时生效。'**
  String get sheetAsrModelSwitchHint;

  /// No description provided for @sheetEndBehavior.
  ///
  /// In zh, this message translates to:
  /// **'篇尾行为'**
  String get sheetEndBehavior;

  /// No description provided for @sheetEndBehaviorStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get sheetEndBehaviorStop;

  /// No description provided for @sheetEndBehaviorLoop.
  ///
  /// In zh, this message translates to:
  /// **'循环'**
  String get sheetEndBehaviorLoop;

  /// No description provided for @readerFinished.
  ///
  /// In zh, this message translates to:
  /// **'已到篇尾'**
  String get readerFinished;

  /// No description provided for @micStatusLoading.
  ///
  /// In zh, this message translates to:
  /// **'引擎加载中'**
  String get micStatusLoading;

  /// No description provided for @micStatusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get micStatusPaused;

  /// No description provided for @micStatusListening.
  ///
  /// In zh, this message translates to:
  /// **'正在收音'**
  String get micStatusListening;

  /// No description provided for @micStatusSilent.
  ///
  /// In zh, this message translates to:
  /// **'未检测到语音'**
  String get micStatusSilent;

  /// No description provided for @micStatusCaptureLost.
  ///
  /// In zh, this message translates to:
  /// **'麦克风中断，正在重连…'**
  String get micStatusCaptureLost;

  /// No description provided for @micStatusEngineStalled.
  ///
  /// In zh, this message translates to:
  /// **'识别引擎无响应'**
  String get micStatusEngineStalled;

  /// No description provided for @micStatusGateStalled.
  ///
  /// In zh, this message translates to:
  /// **'已收音，未匹配稿件'**
  String get micStatusGateStalled;

  /// No description provided for @micStatusLowConfidence.
  ///
  /// In zh, this message translates to:
  /// **'低置信'**
  String get micStatusLowConfidence;

  /// No description provided for @micStatusBackground.
  ///
  /// In zh, this message translates to:
  /// **'后台收音'**
  String get micStatusBackground;

  /// No description provided for @readerRemoteOff.
  ///
  /// In zh, this message translates to:
  /// **'遥控'**
  String get readerRemoteOff;

  /// No description provided for @readerRemoteOn.
  ///
  /// In zh, this message translates to:
  /// **'遥控已开启'**
  String get readerRemoteOn;

  /// No description provided for @remoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'遥控端'**
  String get remoteTitle;

  /// No description provided for @remoteEntryHint.
  ///
  /// In zh, this message translates to:
  /// **'连接另一台设备上的大皖提词器（同一 Wi-Fi）'**
  String get remoteEntryHint;

  /// No description provided for @remoteRemoteHint.
  ///
  /// In zh, this message translates to:
  /// **'在提词页打开「遥控」，用本机扫描二维码或粘贴配对串。'**
  String get remoteRemoteHint;

  /// No description provided for @remotePairingLabel.
  ///
  /// In zh, this message translates to:
  /// **'配对串'**
  String get remotePairingLabel;

  /// No description provided for @remotePairingHint.
  ///
  /// In zh, this message translates to:
  /// **'tps://pair?host=...&port=...&token=...'**
  String get remotePairingHint;

  /// No description provided for @remoteInvalidPairing.
  ///
  /// In zh, this message translates to:
  /// **'配对串无效，请重新复制'**
  String get remoteInvalidPairing;

  /// No description provided for @remoteConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get remoteConnect;

  /// No description provided for @remoteConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接大皖提词器…'**
  String get remoteConnecting;

  /// No description provided for @remoteConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get remoteConnected;

  /// No description provided for @remoteConnectionLost.
  ///
  /// In zh, this message translates to:
  /// **'连接已断开，正在自动重连…'**
  String get remoteConnectionLost;

  /// No description provided for @remoteFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get remoteFailed;

  /// No description provided for @remoteReconnect.
  ///
  /// In zh, this message translates to:
  /// **'重新连接'**
  String get remoteReconnect;

  /// No description provided for @remoteDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get remoteDisconnect;

  /// No description provided for @remotePlaying.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get remotePlaying;

  /// No description provided for @remotePaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get remotePaused;

  /// No description provided for @remoteLineStatus.
  ///
  /// In zh, this message translates to:
  /// **'第 {line} / {total} 行'**
  String remoteLineStatus(int line, int total);

  /// No description provided for @remoteSpeed.
  ///
  /// In zh, this message translates to:
  /// **'{speed} 行/秒'**
  String remoteSpeed(String speed);

  /// No description provided for @remoteMirror.
  ///
  /// In zh, this message translates to:
  /// **'镜像'**
  String get remoteMirror;

  /// No description provided for @remoteLock.
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get remoteLock;

  /// No description provided for @remoteUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get remoteUnlock;

  /// No description provided for @remotePrevLine.
  ///
  /// In zh, this message translates to:
  /// **'上一行'**
  String get remotePrevLine;

  /// No description provided for @remoteNextLine.
  ///
  /// In zh, this message translates to:
  /// **'下一行'**
  String get remoteNextLine;

  /// No description provided for @remotePlay.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get remotePlay;

  /// No description provided for @remotePause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get remotePause;

  /// No description provided for @remoteSpeedDown.
  ///
  /// In zh, this message translates to:
  /// **'降速'**
  String get remoteSpeedDown;

  /// No description provided for @remoteSpeedUp.
  ///
  /// In zh, this message translates to:
  /// **'提速'**
  String get remoteSpeedUp;

  /// No description provided for @remoteHostTitle.
  ///
  /// In zh, this message translates to:
  /// **'遥控提词'**
  String get remoteHostTitle;

  /// No description provided for @remoteHostHint.
  ///
  /// In zh, this message translates to:
  /// **'用另一台设备的「设置 → 遥控端」扫描二维码或粘贴配对串'**
  String get remoteHostHint;

  /// No description provided for @remoteStop.
  ///
  /// In zh, this message translates to:
  /// **'停止遥控'**
  String get remoteStop;

  /// No description provided for @remoteClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get remoteClose;

  /// No description provided for @remoteStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法开启遥控服务（端口可能被占用）'**
  String get remoteStartFailed;

  /// No description provided for @remoteScan.
  ///
  /// In zh, this message translates to:
  /// **'扫码配对'**
  String get remoteScan;

  /// No description provided for @remoteScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描配对二维码'**
  String get remoteScanTitle;

  /// No description provided for @remoteScanHint.
  ///
  /// In zh, this message translates to:
  /// **'对准主控端阅读页的二维码'**
  String get remoteScanHint;

  /// No description provided for @remoteScanBack.
  ///
  /// In zh, this message translates to:
  /// **'改为粘贴配对串'**
  String get remoteScanBack;

  /// No description provided for @remoteScanNotPairing.
  ///
  /// In zh, this message translates to:
  /// **'不是大皖提词器配对二维码'**
  String get remoteScanNotPairing;

  /// No description provided for @remoteScanPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'相机权限被拒绝，请授权或改为粘贴配对串'**
  String get remoteScanPermissionDenied;

  /// No description provided for @remoteScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'相机不可用，请改为粘贴配对串'**
  String get remoteScanFailed;

  /// No description provided for @remoteScanUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持相机扫码，请粘贴配对串'**
  String get remoteScanUnsupported;

  /// No description provided for @readerExternalOff.
  ///
  /// In zh, this message translates to:
  /// **'外接显示'**
  String get readerExternalOff;

  /// No description provided for @readerExternalOn.
  ///
  /// In zh, this message translates to:
  /// **'关闭外接显示'**
  String get readerExternalOn;

  /// No description provided for @externalDisplaySelect.
  ///
  /// In zh, this message translates to:
  /// **'选择外接显示器'**
  String get externalDisplaySelect;

  /// No description provided for @externalDisplayNone.
  ///
  /// In zh, this message translates to:
  /// **'未检测到外接显示器（需 HDMI/DP 或虚拟显示）'**
  String get externalDisplayNone;

  /// No description provided for @externalDisplayHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：无线投屏（Cast）通常是镜像，不是独立副屏。'**
  String get externalDisplayHint;

  /// No description provided for @externalDisplayFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法在外接显示器上显示'**
  String get externalDisplayFailed;

  /// No description provided for @externalDisplayStop.
  ///
  /// In zh, this message translates to:
  /// **'停止外接显示'**
  String get externalDisplayStop;

  /// No description provided for @recordStart.
  ///
  /// In zh, this message translates to:
  /// **'开始录制'**
  String get recordStart;

  /// No description provided for @recordStop.
  ///
  /// In zh, this message translates to:
  /// **'停止录制'**
  String get recordStop;

  /// No description provided for @recordElapsed.
  ///
  /// In zh, this message translates to:
  /// **'录制中 {time}'**
  String recordElapsed(String time);

  /// No description provided for @recordSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存录音'**
  String get recordSaved;

  /// No description provided for @recordSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'录音保存失败'**
  String get recordSaveFailed;

  /// No description provided for @recordPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'麦克风权限被拒绝，无法录制'**
  String get recordPermissionDenied;

  /// No description provided for @recordInProgress.
  ///
  /// In zh, this message translates to:
  /// **'录制中不可开启语音跟随，请先停止录制'**
  String get recordInProgress;

  /// No description provided for @recordHistory.
  ///
  /// In zh, this message translates to:
  /// **'录制历史'**
  String get recordHistory;

  /// No description provided for @recordNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无录音'**
  String get recordNone;

  /// No description provided for @recordReplay.
  ///
  /// In zh, this message translates to:
  /// **'复盘'**
  String get recordReplay;

  /// No description provided for @recordExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get recordExport;

  /// No description provided for @recordDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get recordDelete;

  /// No description provided for @recordDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除这条录音？音频文件将一并删除。'**
  String get recordDeleteConfirm;

  /// No description provided for @recordDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get recordDeleteFailed;

  /// No description provided for @recordReplayFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法播放录音'**
  String get recordReplayFailed;

  /// No description provided for @recordPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get recordPlay;

  /// No description provided for @recordPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get recordPause;

  /// No description provided for @recordExitReplay.
  ///
  /// In zh, this message translates to:
  /// **'退出复盘'**
  String get recordExitReplay;

  /// No description provided for @recordExportDone.
  ///
  /// In zh, this message translates to:
  /// **'已导出 {count} 个文件'**
  String recordExportDone(int count);

  /// No description provided for @recordExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get recordExportFailed;

  /// No description provided for @recordDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长 {time}'**
  String recordDuration(String time);

  /// No description provided for @recordRecordingHint.
  ///
  /// In zh, this message translates to:
  /// **'音频仅保存在本机'**
  String get recordRecordingHint;

  /// No description provided for @settingsSectionDeveloper.
  ///
  /// In zh, this message translates to:
  /// **'实验（开发）'**
  String get settingsSectionDeveloper;

  /// No description provided for @settingsAsrLab.
  ///
  /// In zh, this message translates to:
  /// **'语音实验配置'**
  String get settingsAsrLab;

  /// No description provided for @settingsAsrLabHint.
  ///
  /// In zh, this message translates to:
  /// **'端点与音频采集参数，仅调试构建可见'**
  String get settingsAsrLabHint;

  /// No description provided for @asrLabTitle.
  ///
  /// In zh, this message translates to:
  /// **'语音实验配置'**
  String get asrLabTitle;

  /// No description provided for @asrLabWarning.
  ///
  /// In zh, this message translates to:
  /// **'仅用于开发与真机 A/B。默认值与正式版一致；修改只影响本机，重新开启麦克风后生效。'**
  String get asrLabWarning;

  /// No description provided for @asrLabEndpointSection.
  ///
  /// In zh, this message translates to:
  /// **'端点检测'**
  String get asrLabEndpointSection;

  /// No description provided for @asrLabRule1.
  ///
  /// In zh, this message translates to:
  /// **'句中断句静音（rule1）'**
  String get asrLabRule1;

  /// No description provided for @asrLabRule2.
  ///
  /// In zh, this message translates to:
  /// **'纯静音断句（rule2）'**
  String get asrLabRule2;

  /// No description provided for @asrLabAudioSection.
  ///
  /// In zh, this message translates to:
  /// **'音频采集'**
  String get asrLabAudioSection;

  /// No description provided for @asrLabAudioSource.
  ///
  /// In zh, this message translates to:
  /// **'音频源'**
  String get asrLabAudioSource;

  /// No description provided for @asrLabSourceVoice.
  ///
  /// In zh, this message translates to:
  /// **'语音识别'**
  String get asrLabSourceVoice;

  /// No description provided for @asrLabSourceMic.
  ///
  /// In zh, this message translates to:
  /// **'麦克风'**
  String get asrLabSourceMic;

  /// No description provided for @asrLabAgc.
  ///
  /// In zh, this message translates to:
  /// **'自动增益（AGC）'**
  String get asrLabAgc;

  /// No description provided for @asrLabNs.
  ///
  /// In zh, this message translates to:
  /// **'噪声抑制（NS）'**
  String get asrLabNs;

  /// No description provided for @asrLabAec.
  ///
  /// In zh, this message translates to:
  /// **'回声消除（AEC）'**
  String get asrLabAec;

  /// No description provided for @asrLabBuffer.
  ///
  /// In zh, this message translates to:
  /// **'分片缓冲'**
  String get asrLabBuffer;

  /// No description provided for @asrLabBufferRaw.
  ///
  /// In zh, this message translates to:
  /// **'原始'**
  String get asrLabBufferRaw;

  /// No description provided for @asrLabBufferNote.
  ///
  /// In zh, this message translates to:
  /// **'缓冲越大分片越整，但首字延迟越高；「原始」跟随插件默认分片。'**
  String get asrLabBufferNote;

  /// No description provided for @asrLabCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前配置（随诊断包导出）'**
  String get asrLabCurrent;

  /// No description provided for @asrLabRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get asrLabRestore;

  /// No description provided for @asrLabRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认实验配置'**
  String get asrLabRestored;

  /// No description provided for @asrLabSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，重新开启麦克风后生效'**
  String get asrLabSaved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
