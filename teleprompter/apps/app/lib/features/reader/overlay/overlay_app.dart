import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/reader_settings/overlay_settings.dart';
import '../mic_status.dart';
import 'overlay_channel.dart';

/// 悬浮提词窗口的独立 FlutterEngine 入口（`overlayMain` 在 `main.dart` 注册）。
///
/// 只依赖主阅读页通过 [OverlayChannel] 推送的状态，不访问数据库与录音，
/// 因此窗口可在主 Activity 退到后台后继续显示。
class ReaderOverlayApp extends StatefulWidget {
  const ReaderOverlayApp({super.key});

  @override
  State<ReaderOverlayApp> createState() => _ReaderOverlayAppState();
}

class _ReaderOverlayAppState extends State<ReaderOverlayApp> {
  StreamSubscription<dynamic>? _subscription;
  Timer? _readyRetry;

  List<String> _lines = const [];
  int _anchor = 0;
  String _title = '';
  bool _whiteTheme = false;
  OverlaySettings _settings = OverlaySettings.defaults;
  bool _hasContent = false;

  bool _started = false;
  bool _playing = false;
  bool _locked = false;
  bool _voiceOn = false;
  MicStatusKind? _micStatus;

  @override
  void initState() {
    super.initState();
    _subscription = OverlayBridge.incoming.listen(_onMessage);
    _announceReady();
    // 主阅读页可能尚未完成消息监听；短时重试，避免首次打开时丢消息。
    var attempts = 0;
    _readyRetry = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      if (_hasContent || attempts >= 10) {
        timer.cancel();
        return;
      }
      _announceReady();
    });
  }

  @override
  void dispose() {
    _readyRetry?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _announceReady() {
    unawaited(OverlayBridge.send({'type': OverlayChannel.typeReady}));
  }

  void _onMessage(dynamic message) {
    if (message is! Map) return;
    switch (message['type']) {
      case OverlayChannel.typeInit:
        final rows = message['rows'];
        final lines = message['lines'];
        setState(() {
          // v3 主机下发视觉行；旧主机没有 rows 时回退到语义行。
          final source = rows is List && rows.isNotEmpty ? rows : lines;
          _lines = source is List ? List<String>.from(source) : const [];
          _anchor = (message['anchorRow'] as num?)?.toInt() ??
              (message['anchor'] as num?)?.toInt() ??
              0;
          _title = message['title'] as String? ?? '';
          _whiteTheme = message['theme'] == 'stageWhite';
          _settings = const OverlaySettings()
              .copyWith(
                lineCount: (message['lineCount'] as num?)?.toInt(),
                fontSize: (message['fontSize'] as num?)?.toDouble(),
                opacity: (message['opacity'] as num?)?.toDouble(),
              )
              .normalized();
          _applyState(message);
          _hasContent = true;
        });
        _readyRetry?.cancel();
        break;
      case OverlayChannel.typeAnchor:
        final anchor = (message['anchorRow'] as num?)?.toInt() ??
            (message['anchor'] as num?)?.toInt();
        if (anchor != null && anchor != _anchor) {
          setState(() => _anchor = anchor);
        }
        break;
      case OverlayChannel.typeState:
        setState(() => _applyState(message));
        break;
      case OverlayChannel.typeStyle:
        final next = _settings
            .copyWith(
              widthDp: (message['widthDp'] as num?)?.toInt(),
              opacity: (message['opacity'] as num?)?.toDouble(),
              lineCount: (message['lineCount'] as num?)?.toInt(),
              fontSize: (message['fontSize'] as num?)?.toDouble(),
            )
            .normalized();
        setState(() => _settings = next);
        unawaited(_resizeWindow());
        break;
    }
  }

  void _applyState(Map<dynamic, dynamic> message) {
    _started = message['started'] == true;
    _playing = message['playing'] == true;
    _locked = message['locked'] == true;
    _voiceOn = message['voiceOn'] == true;
    _micStatus = _parseMicStatus(message['micStatus']);
  }

  MicStatusKind? _parseMicStatus(Object? value) {
    if (value is! String) return null;
    for (final status in MicStatusKind.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  Future<void> _resizeWindow() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        _settings.widthDp,
        _settings.heightDp,
        true,
      );
    } catch (_) {
      // 窗口已关闭或平台不支持时忽略。
    }
  }

  void _sendControl(String action) {
    unawaited(
      OverlayBridge.send({
        'type': OverlayChannel.typeControl,
        'action': action,
      }),
    );
  }

  Future<void> _close() async {
    // 位置读取与关闭方法只在主引擎注册；通过消息请求主页面保存位置后关闭。
    await OverlayBridge.send({'type': OverlayChannel.typeClose});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TpTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final palette =
              _whiteTheme ? StagePalette.stageWhite : StagePalette.stageDark;
          return Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.background.withValues(alpha: _settings.opacity),
                borderRadius: BorderRadius.circular(TpTokens.radiusLarge),
                border: Border.all(
                  color: palette.onControlSurface.withValues(alpha: 0.12),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TpTokens.radiusLarge),
                child: Column(
                  children: [
                    _buildHeader(context, palette),
                    Expanded(child: _buildLines(context, palette)),
                    if (_locked)
                      _buildLockedBar(context, palette)
                    else
                      _buildControls(context, palette),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StagePalette palette) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: TpTokens.space2),
          Icon(
            Icons.drag_indicator,
            size: 20,
            color: palette.dimText,
          ),
          const SizedBox(width: TpTokens.space1),
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.dimText,
                fontSize: TpTokens.readerCaptionFontSize,
              ),
            ),
          ),
          if (_voiceOn) _buildMicBadge(context, palette),
          IconButton(
            tooltip: _locked ? l10n.readerLockedBadge : l10n.readerLock,
            visualDensity: VisualDensity.compact,
            onPressed: () => _sendControl(OverlayChannel.actionToggleLock),
            icon: Icon(
              _locked ? Icons.lock : Icons.lock_outline,
              size: 18,
              color: _locked ? palette.highlightBar : palette.onControlSurface,
            ),
          ),
          IconButton(
            tooltip: l10n.overlayCloseTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: _close,
            icon: Icon(
              Icons.close,
              size: 18,
              color: palette.onControlSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicBadge(BuildContext context, StagePalette palette) {
    final l10n = AppLocalizations.of(context);
    final status = _micStatus ?? MicStatusKind.loading;
    final (IconData icon, String label) = switch (status) {
      MicStatusKind.loading => (Icons.hourglass_top, l10n.micStatusLoading),
      MicStatusKind.paused => (Icons.pause_circle_filled, l10n.micStatusPaused),
      MicStatusKind.listening => (Icons.mic, l10n.micStatusListening),
      MicStatusKind.silent => (Icons.mic_off, l10n.micStatusSilent),
      MicStatusKind.captureLost => (
          Icons.mic_none,
          l10n.micStatusCaptureLost,
        ),
      MicStatusKind.engineStalled => (
          Icons.memory,
          l10n.micStatusEngineStalled,
        ),
      MicStatusKind.gateStalled => (
          Icons.sync_problem,
          l10n.micStatusGateStalled,
        ),
      MicStatusKind.lowConfidence => (
          Icons.warning_amber_rounded,
          l10n.micStatusLowConfidence,
        ),
      MicStatusKind.background => (
          Icons.nightlight_round,
          l10n.micStatusBackground,
        ),
    };
    return Container(
      margin: const EdgeInsets.only(right: TpTokens.space1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.highlightBar.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.highlightBar),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.onControlSurface,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, StagePalette palette) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _iconButton(
            tooltip: l10n.readerPrevSentence,
            icon: Icons.keyboard_arrow_up,
            color: palette.onControlSurface,
            onPressed: () => _sendControl(OverlayChannel.actionPrevLine),
          ),
          _iconButton(
            tooltip:
                _started && _playing ? l10n.readerPause : l10n.readerResume,
            icon: _started && _playing ? Icons.pause : Icons.play_arrow,
            color: palette.onControlSurface,
            onPressed: () => _sendControl(OverlayChannel.actionTogglePause),
          ),
          _iconButton(
            tooltip: l10n.readerNextSentence,
            icon: Icons.keyboard_arrow_down,
            color: palette.onControlSurface,
            onPressed: () => _sendControl(OverlayChannel.actionNextLine),
          ),
          _iconButton(
            tooltip: _voiceOn ? l10n.readerVoiceOn : l10n.readerVoiceOff,
            icon: _voiceOn ? Icons.mic : Icons.mic_none,
            color: _voiceOn ? palette.highlightBar : palette.onControlSurface,
            background:
                _voiceOn ? palette.highlightBar.withValues(alpha: 0.16) : null,
            onPressed: () => _sendControl(OverlayChannel.actionToggleMic),
          ),
        ],
      ),
    );
  }

  IconButton _iconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color? background,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      style: background == null
          ? null
          : IconButton.styleFrom(backgroundColor: background),
    );
  }

  Widget _buildLockedBar(BuildContext context, StagePalette palette) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: InkWell(
        onTap: () => _sendControl(OverlayChannel.actionToggleLock),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 14, color: palette.highlightBar),
            const SizedBox(width: TpTokens.space1),
            Text(
              l10n.readerLockedBadge,
              style: TextStyle(
                color: palette.dimText,
                fontSize: TpTokens.readerSmallFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLines(BuildContext context, StagePalette palette) {
    if (!_hasContent || _lines.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n.overlayWaiting,
          style: TextStyle(color: palette.dimText, fontSize: 13),
        ),
      );
    }
    final indices = _visibleIndices();
    final rows = [
      for (final index in indices) _buildLine(index, palette),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpTokens.space2,
        0,
        TpTokens.space2,
        TpTokens.space1,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  List<int> _visibleIndices() {
    final count = _settings.lineCount;
    if (_lines.length <= count) {
      return List<int>.generate(_lines.length, (index) => index);
    }
    final half = count ~/ 2;
    final start =
        (_anchor - half).clamp(0, math.max(0, _lines.length - count)).toInt();
    return List<int>.generate(count, (index) => start + index);
  }

  Widget _buildLine(int index, StagePalette palette) {
    final current = index == _anchor;
    final text = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: current
          ? BoxDecoration(
              color: palette.highlightBackground,
              borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: current ? _settings.fontSize * 0.8 : 0,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: current ? palette.highlightBar : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: current ? palette.text : palette.dimText,
                fontSize: _settings.fontSize,
                height: 1.3,
                fontWeight: TpTokens.readerFontWeight,
                fontFamily: TpTokens.readerFontFamily,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
