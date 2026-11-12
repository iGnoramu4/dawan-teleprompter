import 'dart:async';
import 'dart:math' as math;

import 'package:asr_kit/asr_kit.dart';
import 'package:core_alignment/core_alignment.dart';
import 'package:core_models/core_models.dart';
import 'package:core_reader_layout/core_reader_layout.dart';
import 'package:core_recording/core_recording.dart';
import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/app_log.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/asr_lab/asr_lab_settings.dart';
import '../../shared/dev_flags.dart';
import '../../shared/reader_settings/overlay_settings.dart';
import '../../shared/reader_settings/reader_bar_settings.dart';
import '../../shared/reader_settings/reader_defaults_store.dart';
import '../../shared/reader_settings/reader_settings.dart';
import '../../shared/reader_settings/reader_settings_sheet.dart';
import '../../shared/recording/recording_controller.dart';
import '../../shared/recording/recording_export.dart';
import '../../shared/recording/recording_format.dart';
import '../../shared/recording/recording_history_sheet.dart';
import '../../shared/recording/recording_store.dart';
import '../../shared/recording/replay_controller.dart';
import '../../shared/remote/remote_protocol.dart';
import '../../shared/remote/remote_server.dart';
import 'external_display.dart';
import 'mic_status.dart';
import 'overlay/overlay_channel.dart';
import 'overlay/overlay_window_service.dart';
import 'platform_bridge.dart';
import 'visual_row_measurer.dart';
import 'voice_follow.dart';
import 'voice_health.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.document,
    this.initialAnchor = 0,
    this.initialAnchorModel = 2,
  });

  final ScriptDocument document;

  /// 断点续读锚点（语义行号）。
  final int initialAnchor;

  /// 断点锚点的语义行模型：2 = 整篇连续文本（当前唯一模型）。
  final int initialAnchorModel;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ScriptRepository _repository;

  late ScriptModel _script;
  late ScriptIndex _index;
  late AlignTracker _tracker;
  late final Ticker _ticker;
  late Map<int, List<ScriptMarker>> _markersByLine;

  ReaderSettings _settings = ReaderSettings.defaults;
  StagePalette get _palette => _settings.theme == ReaderTheme.stageWhite
      ? StagePalette.stageWhite
      : StagePalette.stageDark;

  final ReadingFollower _follower = ReadingFollower();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  final ValueNotifier<double> _fade = ValueNotifier<double>(1);

  double _lastTickSeconds = 0;
  bool _paused = true;

  /// 是否已经开始过（首次进入页面必须由用户点击屏幕或开始控件）。
  bool _started = false;
  bool _voiceOn = false;
  int _anchor = 0;

  /// 当前锚点在语义行内的字符偏移。
  int _anchorChar = 0;
  bool _initialAnchorApplied = false;

  /// 语音引擎是否就绪（模型加载与麦克风启动完成）。
  bool _voiceReady = false;
  bool _appResumed = true;
  int _lastVoiceAtMs = 0;

  /// 收音健康度（采集断流 / 引擎卡死 / 静音 / 正常），由语音会话每秒评估。
  VoiceHealthKind _voiceHealth = VoiceHealthKind.idle;

  /// 闸门卡住：有识别文本但锚点长时间不推进。
  bool _gateStalled = false;
  int _anchorSeen = 0;
  int _lastAnchorAdvanceMs = 0;

  /// 逐行推进闸门：参数由当前语音匹配档位决定（C-09）。
  LineStepGate _lineGate =
      LineStepGate.fromProfile(MatchProfile.standardProfile);

  /// 控制面板 3 s 无操作自动淡出（§19.8）。
  bool _panelVisible = true;

  /// 用户手动隐藏功能栏；全局持久化，跨台本与重启保持。
  bool _panelHidden = false;
  Timer? _panelTimer;

  /// 功能栏上显示哪些按钮（全局配置，默认只留跟随控制）。
  List<ReaderBarAction> _barActions = defaultReaderBarActions;

  /// 锁定后屏蔽手势，仅留解锁提示（C-08）。
  bool _locked = false;
  bool _dragging = false;

  Timer? _presetTimer;

  double _confidence = 0;
  bool _degraded = false;
  int _lastFollowLogMs = 0;
  int _lastAlignBlockedLogMs = 0;

  /// 行级读音覆盖率：整行覆盖达标即放行到下一行。
  late LineCoverageTracker _coverage;

  /// 连续朗读检测：连续有输出且锚点在推进时放宽闸门。
  final ContinuousSpeechMonitor _speechMonitor = ContinuousSpeechMonitor();
  int _lastGateModeLogMs = 0;

  /// 端到端延迟补偿：估计延迟（ms）与前馈行数（0 = 未补偿）。
  double _latencyEstimateMs = 0;
  double _rowsPerSecond = 0.8;
  int _lastVoiceRow = -1;
  int _lastVoiceRowAtMs = 0;
  int _lastLatencyLogMs = 0;

  LayoutSnapshot? _snapshot;
  ReadingBand? _band;
  String _snapshotKey = '';

  /// 舞台子树缓存：partial 每次更新都会 setState，但正文只依赖
  /// 「排版快照 + 当前视觉行 + 主题/对齐」，与段内字符推进无关。
  /// 返回同一个 Widget 实例时 Flutter 会跳过整棵子树的 update。
  Widget? _stageCache;
  String _stageCacheKey = '';
  final int _snapshotRevision = 0;
  double _viewportH = 0;
  double _viewportW = 0;
  double _stageWidth = 0;
  double _stageLeft = 0;

  /// 语音吸附起点（ms），用于记录单次吸附的实际时长。
  int _snapStartMs = 0;

  /// 篇尾完成态：读到末行并静止后置真；循环模式会延时回到篇首。
  bool _finished = false;
  Timer? _loopTimer;

  /// 末行静止计时（秒）：连续静止 0.6 s 才判定篇尾，避免瞬停误触发。
  double _endRestMs = 0;

  /// early arm：当前行尾部 + 下一行前缀命中，连续 2 次或 final 才提前跨行。
  EarlyArmDetector? _earlyArm;

  VoiceFollowSession? _session;

  /// 系统级悬浮窗（W-02）：主页面与浮窗引擎的跨引擎消息。
  OverlayWindowService? _overlayService;
  OverlaySettings _overlaySettings = OverlaySettings.defaults;
  StreamSubscription<dynamic>? _overlaySubscription;
  Timer? _overlayTimer;
  bool _overlayOn = false;
  int _lastOverlayRow = -1;
  String _lastOverlayState = '';

  /// 局域网遥控（E6）：主控端服务，仅在阅读页存活期间运行。
  RemoteServer? _remoteServer;
  RemotePairing? _remotePairing;
  bool _remoteOn = false;

  /// 行号坐标系的布局版本：行宽/字号变化后由快照键区分，供遥控端丢弃缓存。
  final int _layoutVersion = 1;

  /// 外接显示（E7-1）：向 HDMI/DP 副屏输出纯稿件。
  ExternalDisplayService? _displayService;
  StreamSubscription<int>? _displayRemovedSub;
  Timer? _displayTimer;
  bool _displayOn = false;
  int? _displayId;
  String _lastDisplaySignature = '';

  /// M2 录制 + 时间轴（E8-1）：音频与行号采样并行进行。
  RecordingController? _recording;
  Timer? _recordUiTimer;
  bool _recordingOn = false;
  int _recordElapsedMs = 0;

  /// M2 复盘（E8-2）：音频位置驱动稿件行号。
  ReplayController? _replay;
  bool _replayOn = false;
  bool _replayPlaying = false;
  Duration _replayPosition = Duration.zero;

  /// 帧耗时采样（M1-c：高速滚动流畅度可验证）。
  final List<FrameTiming> _frameTimings = <FrameTiming>[];

  @override
  void initState() {
    super.initState();
    _repository = ref.read(scriptRepositoryProvider);
    _script = _buildModel();
    _markersByLine = _buildMarkerMap();
    _anchor = widget.initialAnchor.clamp(
      0,
      math.max(0, _script.lines.length - 1),
    );
    if (widget.initialAnchorModel < 2) {
      // 旧断点坐标属于已移除的分段/按句切行模型，不再兼容，从头开始。
      _anchor = 0;
      _anchorChar = 0;
    }
    _index = ScriptIndex.build(
      _script.lines.map((line) => line.text).toList(),
    );
    _tracker = AlignTracker.fromProfile(
      MatchProfile.of(_settings.matchTolerance),
      lineCount: _script.lines.length,
    );
    _earlyArm = EarlyArmDetector.fromProfile(
      _index,
      MatchProfile.of(_settings.matchTolerance),
    );
    _coverage = LineCoverageTracker(_index);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    AppLog.instance.event('reader', 'open', {
      'script': widget.document.id,
      'lines': _script.lines.length,
      'anchor': _anchor,
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_repository.touchLastViewed(widget.document.id));
    unawaited(_loadSettings());
    unawaited(_applyWakelock(true));
    _overlayService = OverlayWindowService(_repository);
    _overlaySubscription = OverlayBridge.incoming.listen(_onOverlayMessage);
    _displayService = ExternalDisplayService();
    _displayRemovedSub =
        _displayService!.removedDisplays.listen(_onDisplayRemoved);
    _resetPanelTimer();
  }

  /// 提词页只认整篇连续文本，`rawText` 是唯一正文来源。
  ScriptModel _buildModel() {
    final document = widget.document;
    return ScriptModel.parse(
      id: document.id,
      title: document.title,
      rawText: document.rawText,
    );
  }

  Map<int, List<ScriptMarker>> _buildMarkerMap() => mapMarkersToContinuousLines(
        rawText: _script.rawText,
        markers: widget.document.markers,
        lines: _script.lines,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed != _appResumed && mounted) {
      setState(() => _appResumed = resumed);
    }
    _pushOverlayState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presetTimer?.cancel();
    _overlayTimer?.cancel();
    unawaited(_overlaySubscription?.cancel());
    if (_overlayOn) unawaited(_overlayService?.close());
    unawaited(_remoteServer?.stop());
    _displayTimer?.cancel();
    unawaited(_displayRemovedSub?.cancel());
    if (_displayOn) unawaited(_displayService?.hide());
    _displayService?.dispose();
    _recordUiTimer?.cancel();
    unawaited(_recording?.dispose());
    unawaited(_replay?.dispose());
    unawaited(_savePreset());
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _logFrameSummary();
    _ticker.dispose();
    unawaited(_session?.dispose());
    unawaited(PlatformBridge.stopVoiceService());
    unawaited(_repository.saveAnchor(widget.document.id, _anchor));
    unawaited(_repository.touchLastViewed(widget.document.id));
    unawaited(WakelockPlus.disable());
    _panelTimer?.cancel();
    _loopTimer?.cancel();
    _offset.dispose();
    _fade.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ------------------------------------------------------------ 设置与预设

  Future<void> _loadSettings() async {
    // 优先级：台本预设 > 全局默认 > 内置默认（C-06 + M1-c）。
    final json = await _repository.loadPreset('script:${widget.document.id}');
    ReaderSettings? loaded;
    if (json != null) {
      loaded = ReaderSettings.fromJson(json);
    } else {
      loaded = await loadGlobalReaderDefaults(_repository);
    }
    final hidden = await loadReaderPanelHidden(_repository);
    final barActions = await loadReaderBarActions(_repository);
    if (!mounted) return;
    setState(() => _barActions = barActions);
    if (hidden) {
      _panelTimer?.cancel();
      setState(() {
        _panelHidden = true;
        _panelVisible = false;
      });
    }
    if (loaded == null) return;
    _applySettings(loaded, persist: false);
    AppLog.instance.event('reader', 'settings_loaded', {
      'script': widget.document.id,
      'source': json != null ? 'script' : 'global_default',
      'fontSize': _settings.fontSize,
      'theme': _settings.theme.name,
    });
  }

  void _applySettings(ReaderSettings next, {bool persist = true}) {
    if (!mounted) return;
    final previous = _settings;
    setState(() => _settings = next.normalized());
    _follower.snapDuration =
        ReadingFollower.snapDurationFromSmoothness(_settings.smoothness);
    unawaited(_applyWakelock(_settings.keepScreenOn));
    if (previous.matchTolerance != _settings.matchTolerance) {
      final profile = MatchProfile.of(_settings.matchTolerance);
      _lineGate = LineStepGate.fromProfile(profile);
      _tracker.applyProfile(profile);
    }
    if (previous.latencyCompensation != _settings.latencyCompensation) {
      _resetLatencyCompensation();
    }
    if (persist) {
      _schedulePresetSave();
      AppLog.instance.event('reader', 'settings_changed', {
        'fontSize': _settings.fontSize,
        'lineHeight': _settings.lineHeight,
        'leftMargin': _settings.leftMargin,
        'rightMargin': _settings.rightMargin,
        'matchTolerance': _settings.matchTolerance.name,
        'latencyCompensation': _settings.latencyCompensation,
        'speed': _settings.speed,
        'theme': _settings.theme.name,
        'mirrorX': _settings.mirrorX,
        'mirrorY': _settings.mirrorY,
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _retargetAnchor();
    });
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    // 上限约 1 分钟 60fps，避免长时间阅读占用内存。
    if (_frameTimings.length >= 3600) return;
    _frameTimings.addAll(timings);
  }

  void _logFrameSummary() {
    final timings = _frameTimings;
    if (timings.length < 50) return;
    final build = timings
        .map((t) => t.buildDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    final total = timings
        .map((t) => t.totalSpan.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    double p95(List<double> values) => values.isEmpty
        ? 0
        : values[(values.length * 0.95).floor().clamp(0, values.length - 1)];
    double avg(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
    final janky = total.where((span) => span > 33.3).length;
    AppLog.instance.event('reader', 'frame_summary', {
      'script': widget.document.id,
      'frames': timings.length,
      'avgBuildMs': _round(avg(build)),
      'p95BuildMs': _round(p95(build)),
      'avgRasterMs': _round(avg(raster)),
      'p95RasterMs': _round(p95(raster)),
      'p95TotalMs': _round(p95(total)),
      'jankyFrames': janky,
      'speed': _settings.speed,
    });
  }

  double _round(double value) => (value * 100).roundToDouble() / 100;

  void _schedulePresetSave() {
    _presetTimer?.cancel();
    _presetTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_savePreset());
    });
  }

  Future<void> _savePreset() async {
    try {
      await _repository.savePreset(
        'script:${widget.document.id}',
        _settings.toJson(),
      );
    } catch (_) {
      // 预设写失败不影响阅读。
    }
  }

  Future<void> _applyWakelock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // 不支持常亮的平台静默降级。
    }
  }

  // -------------------------------------------------------------- 悬浮提词

  void _onOverlayMessage(dynamic message) {
    if (message is! Map) return;
    switch (message['type']) {
      case OverlayChannel.typeReady:
        _sendOverlayInit();
        break;
      case OverlayChannel.typePosition:
        final x = (message['x'] as num?)?.toDouble();
        final y = (message['y'] as num?)?.toDouble();
        if (x == null || y == null) return;
        _overlaySettings = _overlaySettings.copyWith(x: x, y: y);
        unawaited(_persistOverlaySettings());
        break;
      case OverlayChannel.typeClose:
        // 浮窗引擎无法直接调用关闭方法，这里由主页面执行并保存位置。
        unawaited(_closeOverlay());
        break;
      case OverlayChannel.typeControl:
        _handleOverlayControl(message['action']);
        break;
    }
  }

  /// 浮窗上的控制动作回到主阅读页执行，保持两条入口同一状态。
  void _handleOverlayControl(Object? action) {
    switch (action) {
      case OverlayChannel.actionTogglePause:
        if (!_locked) _togglePause();
        break;
      case OverlayChannel.actionPrevLine:
        if (!_locked) _jumpLines(-1);
        break;
      case OverlayChannel.actionNextLine:
        if (!_locked) _jumpLines(1);
        break;
      case OverlayChannel.actionToggleMic:
        if (!_locked) unawaited(_toggleMic());
        break;
      case OverlayChannel.actionToggleLock:
        if (_locked) {
          _unlock();
        } else {
          _lock();
        }
        break;
    }
  }

  MicStatusKind _overlayMicStatus() {
    return resolveMicStatus(
      voiceOn: _voiceOn,
      ready: _voiceReady,
      paused: _paused,
      // 浮窗场景下主 Activity 本就可能处于后台，收音角标按可用状态显示。
      appResumed: true,
      degraded: _degraded,
      confidence: _confidence,
      health: _voiceHealth,
      gateStalled: _gateStalled,
    );
  }

  Map<String, Object?> _overlayStatePayload() {
    return {
      'type': OverlayChannel.typeState,
      'started': _started,
      'playing': _started && !_paused,
      'locked': _locked,
      'voiceOn': _voiceOn,
      'micStatus': _voiceOn ? _overlayMicStatus().name : null,
    };
  }

  String _overlayStateSignature() {
    return '${_started ? 1 : 0}|${_paused ? 1 : 0}|'
        '${_locked ? 1 : 0}|${_voiceOn ? 1 : 0}|'
        '${_voiceOn ? _overlayMicStatus().name : ''}';
  }

  Future<void> _persistOverlaySettings() async {
    try {
      await _overlayService?.saveSettings(_overlaySettings);
    } catch (_) {
      // 悬浮窗参数写失败不影响当前会话。
    }
  }

  /// 锚点所在的视觉行（整篇连续文本的一行会折成多条视觉行）。
  int get _anchorRow => _snapshot?.rowForChar(_anchor, _anchorChar) ?? 0;

  /// 当前排版下的视觉行文本（悬浮窗/外接屏/字幕使用）。
  List<String> get _visualLines =>
      _snapshot?.rows.map((row) => row.text).toList(growable: false) ??
      const <String>[];

  void _sendOverlayInit() {
    unawaited(
      OverlayBridge.send({
        ..._overlayStatePayload(),
        'type': OverlayChannel.typeInit,
        'title': _script.title,
        'lines': _script.lines.map((line) => line.text).toList(growable: false),
        'anchor': _anchor,
        // v3：视觉行与行内偏移；旧悬浮窗忽略并回退到 lines/anchor。
        'rows': _visualLines,
        'anchorRow': _anchorRow,
        'anchorOffset': _anchorChar,
        'lineCount': _overlaySettings.lineCount,
        'fontSize': _overlaySettings.fontSize,
        'opacity': _overlaySettings.opacity,
        'theme': _settings.theme.name,
        'layoutVersion': _layoutVersion,
        'bandRatio': _settings.readAheadRatio,
        'rowHeight': _band?.rowHeight ?? 0,
        'typographyModel': ReaderSettings.currentTypographyModel,
      }),
    );
    _lastOverlayRow = _anchorRow;
    _lastOverlayState = _overlayStateSignature();
  }

  void _pushOverlayState({bool force = false}) {
    if (!_overlayOn) return;
    final signature = _overlayStateSignature();
    if (!force && signature == _lastOverlayState) return;
    _lastOverlayState = signature;
    unawaited(OverlayBridge.send(_overlayStatePayload()));
  }

  void _pushOverlayAnchor() {
    if (!_overlayOn) return;
    final row = _anchorRow;
    if (row != _lastOverlayRow) {
      _lastOverlayRow = row;
      unawaited(
        OverlayBridge.send({
          'type': OverlayChannel.typeAnchor,
          'anchor': _anchor,
          'anchorRow': row,
          'anchorOffset': _anchorChar,
        }),
      );
    }
    _pushOverlayState();
  }

  void _sendOverlayStyle() {
    unawaited(
      OverlayBridge.send({
        'type': OverlayChannel.typeStyle,
        'widthDp': _overlaySettings.widthDp,
        'opacity': _overlaySettings.opacity,
        'lineCount': _overlaySettings.lineCount,
        'fontSize': _overlaySettings.fontSize,
      }),
    );
  }

  /// 设置面板实时调节：主画布不变，正在显示的浮窗立即重排。
  void _applyOverlaySettings(OverlaySettings next) {
    final normalized = next.normalized();
    if (mounted) {
      setState(() => _overlaySettings = normalized);
    } else {
      _overlaySettings = normalized;
    }
    unawaited(_persistOverlaySettings());
    if (_overlayOn) _sendOverlayStyle();
  }

  Future<void> _ensureNotificationPermission() async {
    if (await PlatformBridge.notificationGranted()) return;
    final granted = await PlatformBridge.requestNotification();
    if (granted) return;
    AppLog.instance.event('permission', 'notification_denied');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).overlayNotificationDenied,
        ),
      ),
    );
  }

  Future<void> _toggleOverlay() async {
    if (_overlayOn) {
      await _closeOverlay();
      return;
    }
    final service = _overlayService;
    if (service == null) return;
    var granted = await service.isPermissionGranted();
    if (!granted) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.overlayPermissionTitle),
          content: Text(l10n.overlayPermissionBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.overlayPermissionAction),
            ),
          ],
        ),
      );
      if (go != true) return;
      granted = await service.requestPermission();
    }
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).overlayPermissionDenied),
        ),
      );
      AppLog.instance.event('overlay', 'permission_denied');
      return;
    }
    await _ensureNotificationPermission();
    final settings = (await service.loadSettings()).normalized();
    if (!mounted) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    _overlaySettings = settings;
    try {
      await service.show(
        settings: settings,
        title: AppLocalizations.of(context).overlayNotificationTitle,
        devicePixelRatio: pixelRatio,
      );
    } catch (error) {
      AppLog.instance.event('overlay', 'show_failed', {
        'error': error.runtimeType.toString(),
      });
      return;
    }
    if (!mounted) return;
    setState(() => _overlayOn = true);
    _lastOverlayRow = -1;
    _lastOverlayState = '';
    _overlayTimer?.cancel();
    _overlayTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _pushOverlayAnchor(),
    );
    _sendOverlayInit();
    AppLog.instance.event('overlay', 'show', {
      'widthDp': settings.widthDp,
      'lineCount': settings.lineCount,
    });
  }

  Future<void> _closeOverlay() async {
    final service = _overlayService;
    _overlayTimer?.cancel();
    _overlayTimer = null;
    final position = await service?.currentPosition();
    if (position != null) {
      _overlaySettings = _overlaySettings.copyWith(
        x: position.x,
        y: position.y,
      );
      await _persistOverlaySettings();
    }
    await service?.close();
    if (mounted) setState(() => _overlayOn = false);
    AppLog.instance.event('overlay', 'close');
  }

  // ---------------------------------------------------------------- 局域网遥控

  Future<void> _openRemote() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    var pairing = _remotePairing;
    if (!_remoteOn || pairing == null) {
      final server = RemoteServer(
        stateProvider: _remoteStateSnapshot,
        onCommand: (RemoteCommand command) async =>
            _handleRemoteCommand(command),
      );
      try {
        pairing = await server.start();
      } catch (error) {
        AppLog.instance.event('remote', 'start_failed', {
          'error': error.runtimeType.toString(),
        });
        await server.stop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.remoteStartFailed)),
        );
        return;
      }
      if (!mounted) {
        await server.stop();
        return;
      }
      _remoteServer = server;
      _remotePairing = pairing;
      setState(() => _remoteOn = true);
      AppLog.instance.event('remote', 'started', {'port': server.boundPort});
    }
    final uri = pairing.toUriString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.remoteHostTitle),
        content: SizedBox(
          width: 280,
          // 固定宽度：AlertDialog 会向内容查询固有宽度，而 QrImageView
          // 内部使用 LayoutBuilder，无法参与固有尺寸计算。
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: uri,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: TpTokens.space3),
                SelectableText(uri, textAlign: TextAlign.center),
                const SizedBox(height: TpTokens.space2),
                Text(
                  l10n.remoteHostHint,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(_stopRemote());
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.remoteStop),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.remoteClose),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRemote() async {
    final server = _remoteServer;
    _remoteServer = null;
    _remotePairing = null;
    if (mounted) setState(() => _remoteOn = false);
    await server?.stop();
    AppLog.instance.event('remote', 'stopped');
  }

  /// 主控端状态快照：只发行号与当前行文本，遥控端不做像素换算。
  RemoteState _remoteStateSnapshot() {
    final lines = _script.lines;
    final anchor = lines.isEmpty ? 0 : _anchor.clamp(0, lines.length - 1);
    var text = lines.isEmpty ? '' : lines[anchor].text;
    if (text.length > RemoteState.maxAnchorTextLength) {
      text = '${text.substring(0, RemoteState.maxAnchorTextLength)}…';
    }
    final rows = _snapshot?.rows ?? const <VisualRow>[];
    final anchorRow = rows.isEmpty ? 0 : _anchorRow.clamp(0, rows.length - 1);
    var rowText = rows.isEmpty ? '' : rows[anchorRow].text;
    if (rowText.length > RemoteState.maxAnchorTextLength) {
      rowText = '${rowText.substring(0, RemoteState.maxAnchorTextLength)}…';
    }
    return RemoteState(
      anchorLine: anchor,
      anchorOffset: _anchorChar,
      anchorRow: anchorRow,
      layoutVersion: _layoutVersion,
      confidence: _confidence,
      speed: _settings.speed,
      playing: _started && !_paused,
      scriptTitle: _script.title,
      progress: lines.isEmpty ? 0 : (anchor + 1) / lines.length,
      rowProgress: rows.isEmpty ? 0 : (anchorRow + 1) / rows.length,
      mirrored: _settings.mirrorX,
      locked: _locked,
      lineCount: lines.length,
      lineUnit: RemoteState.lineUnitParagraph,
      anchorText: text,
      anchorRowText: rowText,
      rowHeight: _band?.rowHeight ?? 0,
      rowCount: rows.length,
      bandRatio: _settings.readAheadRatio,
      typographyModel: ReaderSettings.currentTypographyModel,
    );
  }

  void _handleRemoteCommand(RemoteCommand command) {
    if (!mounted) return;
    switch (command.action) {
      case RemoteProtocol.actionPlay:
        if (_locked) return;
        if (!_started) {
          _start();
        } else if (_paused) {
          _togglePause();
        }
      case RemoteProtocol.actionPause:
        if (_locked) return;
        if (_started && !_paused) _togglePause();
      case RemoteProtocol.actionNextLine:
        if (!_locked) _jumpLines(1);
      case RemoteProtocol.actionPrevLine:
        if (!_locked) _jumpLines(-1);
      case RemoteProtocol.actionSpeed:
        if (!_locked && command.delta != null) _adjustSpeed(command.delta!);
      case RemoteProtocol.actionScroll:
        final delta = command.delta;
        if (!_locked && delta != null && delta != 0) {
          _jumpLines(delta.round());
        }
      case RemoteProtocol.actionJump:
        if (_locked) break;
        final line = command.line;
        if (line != null) _jumpToLine(line);
      case RemoteProtocol.actionMirror:
        final value = command.value;
        if (value != null) {
          _applySettings(_settings.copyWith(mirrorX: value));
        }
      case RemoteProtocol.actionLock:
        if (command.value == true) {
          _lock();
        } else if (command.value == false) {
          _unlock();
        }
    }
    AppLog.instance.event('remote', 'command', {'action': command.action});
  }

  // ------------------------------------------------------------ 外接显示（E7）

  /// 外接屏/悬浮窗输出的行：优先使用视觉行，未完成排版时回退到语义行。
  List<String> get _displayLines {
    final rows = _visualLines;
    if (rows.isNotEmpty) return rows;
    return _script.lines.map((line) => line.text).toList(growable: false);
  }

  int get _displayAnchor => _visualLines.isNotEmpty ? _anchorRow : _anchor;

  String _displaySignature() =>
      '$_displayAnchor|${_displayLines.length}|$_layoutVersion|'
      '${_settings.fontSize}|${_settings.mirrorX}|'
      '${_settings.readAheadRatio}';

  Future<void> _openExternalDisplay() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    if (_displayOn) {
      await _stopExternalDisplay();
      return;
    }
    final displays = await _displayService!.listDisplays();
    if (!mounted) return;
    final candidates =
        displays.where((display) => display.presentation).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.externalDisplayNone)));
      return;
    }
    var display = candidates.first;
    if (candidates.length > 1) {
      final selected = await showDialog<ExternalDisplay>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(l10n.externalDisplaySelect),
          children: [
            for (final candidate in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, candidate),
                child: Text(
                  '${candidate.name} · ${candidate.width}×${candidate.height}',
                ),
              ),
          ],
        ),
      );
      if (selected == null) return;
      display = selected;
    }
    await _startExternalDisplay(display);
  }

  Future<void> _startExternalDisplay(ExternalDisplay display) async {
    final ok = await _displayService!.show(
      displayId: display.id,
      lines: _displayLines,
      anchor: _displayAnchor,
      fontSize: _settings.fontSize,
      mirrored: _settings.mirrorX,
      bandRatio: _settings.readAheadRatio,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).externalDisplayFailed),
        ),
      );
      return;
    }
    _displayOn = true;
    _displayId = display.id;
    _lastDisplaySignature = _displaySignature();
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _pushExternalDisplay(),
    );
    setState(() {});
    AppLog.instance.event('display', 'show', {
      'display': display.id,
      'width': display.width,
      'height': display.height,
    });
  }

  Future<void> _stopExternalDisplay() async {
    _displayTimer?.cancel();
    _displayTimer = null;
    _displayOn = false;
    _displayId = null;
    await _displayService?.hide();
    if (mounted) setState(() {});
    AppLog.instance.event('display', 'hide');
  }

  void _pushExternalDisplay() {
    if (!_displayOn) return;
    final signature = _displaySignature();
    if (signature == _lastDisplaySignature) return;
    _lastDisplaySignature = signature;
    unawaited(
      _displayService!.update(
        lines: _displayLines,
        anchor: _displayAnchor,
        fontSize: _settings.fontSize,
        mirrored: _settings.mirrorX,
        bandRatio: _settings.readAheadRatio,
      ),
    );
  }

  void _onDisplayRemoved(int id) {
    if (!_displayOn || id != _displayId) return;
    _displayTimer?.cancel();
    _displayTimer = null;
    _displayOn = false;
    _displayId = null;
    if (mounted) setState(() {});
    AppLog.instance.event('display', 'removed', {'display': id});
  }

  // -------------------------------------------------------------- 渲染与布局
  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    var dt = now - _lastTickSeconds;
    _lastTickSeconds = now;
    if (dt <= 0 || dt > 0.12) dt = 1 / 60;

    if (_voiceOn) {
      if (_paused && !_follower.flinging) {
        _follower.freeze();
      } else {
        _follower.unfreeze();
      }
      _updateGateStall();
    } else if (!_paused) {
      _follower.advanceManual(dt, linesPerSecond: _settings.speed);
      _syncAnchorFromPosition();
    }

    final flinging = _follower.flinging;
    final wasSnapping = _follower.snapping;
    final snapSegments = _follower.snapSegments;
    _follower.step(dt);
    if (!_follower.snapping && wasSnapping) {
      AppLog.instance.event('voice', 'snap', {
        'ms': DateTime.now().millisecondsSinceEpoch - _snapStartMs,
        'rows': snapSegments,
      });
    }
    if (flinging) _syncAnchorFromPosition();
    if ((_offset.value - _follower.position).abs() > 0.01) {
      _offset.value = _follower.position;
    }
    if ((_fade.value - _follower.fadeOpacity).abs() > 0.01) {
      _fade.value = _follower.fadeOpacity;
    }

    // 篇尾：末行目标已稳定 0.6 s 才判定，避免中途瞬时静止误触发。
    if (_started && !_paused && !_finished) {
      final snapshot = _snapshot;
      final atEnd = snapshot != null &&
          snapshot.rowCount > 0 &&
          _anchor >= _script.lines.length - 1 &&
          _follower.position >= _follower.maxScroll - 0.5;
      // 手动模式每帧都在推进位置（不会进入 atRest），只以到达边界为准。
      final settled = !_voiceOn || _follower.atRest;
      if (atEnd && settled) {
        _endRestMs += dt;
        if (_endRestMs >= 0.6) _handleFinished();
      } else {
        _endRestMs = 0;
      }
    } else {
      _endRestMs = 0;
    }
  }

  /// 篇尾完成态：默认暂停并显示「已到篇尾」；循环模式延时回到篇首。
  void _handleFinished() {
    if (_finished || !mounted) return;
    final loop = _settings.endBehavior == ReaderEndBehavior.loop;
    _endRestMs = 0;
    setState(() {
      _finished = true;
      _paused = true;
    });
    _follower.freeze();
    _pushOverlayState();
    AppLog.instance.event('reader', 'finished', {
      'script': widget.document.id,
      'line': _anchor,
      'mode': _voiceOn ? 'voice' : 'manual',
      'endBehavior': _settings.endBehavior.name,
    });
    if (!loop) return;
    _loopTimer?.cancel();
    _loopTimer = Timer(const Duration(milliseconds: 1200), _restartLoop);
  }

  /// 循环模式回到篇首：保留语音与录制会话，只重置锚点与对齐状态。
  void _restartLoop() {
    _loopTimer = null;
    if (!mounted || !_finished) return;
    setState(() {
      _finished = false;
      _anchor = 0;
      _anchorChar = 0;
      _paused = false;
      _confidence = 0;
      _degraded = false;
      _lastVoiceAtMs = DateTime.now().millisecondsSinceEpoch;
    });
    _resetFollowState();
    _jumpFollowerToRow(0);
    _follower.unfreeze();
    _pushOverlayState();
    AppLog.instance.event('reader', 'restart_from_end', {
      'script': widget.document.id,
      'voice': _voiceOn,
    });
  }

  /// 复位语音推进与篇尾状态（开始 / 恢复 / 循环）。
  void _resetFollowState() {
    _tracker.forceLine(_anchor);
    _lineGate.reset();
    _earlyArm?.reset();
    _endRestMs = 0;
  }

  void _syncAnchorFromPosition() {
    final snapshot = _snapshot;
    final band = _band;
    if (snapshot == null || band == null || snapshot.rowCount == 0) return;
    final row = _rowAtPosition(_follower.position);
    final currentRow = snapshot.rowForChar(_anchor, _anchorChar);
    if (row == currentRow) return;
    final line = snapshot.lineOfRow(row);
    final charOffset = snapshot.rows[row].charStart;
    setState(() {
      _anchor = line;
      _anchorChar = charOffset;
    });
    // 用户手动滚动后，跟踪器必须跟页面一起落位：否则对齐窗口仍停在旧行，
    // 文本与窗口错位后置信度会掉到 0.1，闸门再也放不行（页面冻死）。
    _tracker.forceLine(line);
    _lineGate.reset();
    _coverage.reset();
    _earlyArm?.reset();
    _jumpBudget.reset();
  }

  /// 内容坐标偏移：垂直镜像时把「行 0 走进阅读带」换算到镜像后的坐标。
  double get _positionOffset {
    final band = _band;
    if (band == null || !_settings.mirrorY) return 0;
    return 2 * band.bandTop - _viewportH - _settings.prismDy * _viewportH;
  }

  int _rowAtPosition(double position) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return 0;
    if (snapshot.pitch <= 0) return 0;
    final row = ((position - _positionOffset) / snapshot.pitch).round();
    return row.clamp(0, snapshot.rowCount - 1);
  }

  double _targetForRow(int row) {
    final band = _band;
    if (band == null) return 0;
    return band.targetForRowWithMirror(row, mirrorY: _settings.mirrorY);
  }

  void _jumpFollowerToRow(int row, {bool fade = true}) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final target = _targetForRow(row.clamp(0, snapshot.rowCount - 1));
    if (fade) {
      _follower.jumpToWithFade(target);
    } else {
      _follower.jumpTo(target);
    }
    _offset.value = _follower.position;
  }

  /// 累计跳行预算：单次 3 行只夹单步，连续多次 3 行仍会累计冲出很远。
  ///
  /// 任意 10 秒内跳行总和不超过 3 行，用尽后只允许逐行推进。
  final AutoAdvanceBudget _jumpBudget = AutoAdvanceBudget();

  /// 语音推进（闸门或 early arm）统一入口：更新锚点并设置视觉行目标。
  void _advanceTo(int line, int charOffset) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return;
    final raw = line.clamp(0, _script.lines.length - 1).toInt();
    // 所有自动推进（对齐/闸门/覆盖率/early arm/重锚）都经过这里，
    // 累计跳行上限也只在这里夹一次，避免各通道叠加绕过。
    final target = _jumpBudget.limit(
      from: _anchor,
      to: raw,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final offset = (target == raw ? charOffset : 0)
        .clamp(0, _script.lines[target].text.length)
        .toInt();
    // 锚点单调不后退：任何自动推进（对齐/闸门/early arm）都不能把位置往回带，
    // 回退只允许用户显式跳行或时间轴拖动。
    if (target < _anchor) return;
    if (target == _anchor && offset < _anchorChar) return;
    final row = snapshot.rowForChar(target, offset);
    final rowChanged = row != snapshot.rowForChar(_anchor, _anchorChar);
    if (target != _anchor || offset != _anchorChar) {
      if (rowChanged) {
        setState(() {
          _anchor = target;
          _anchorChar = offset;
        });
      } else {
        // 段内字符推进但视觉行未变：无需重建整页，只更新锚点供上报/录制。
        _anchor = target;
        _anchorChar = offset;
      }
    }
    // 语音跟随只认整行：当前视觉行吸附到阅读带（下划线）位置，逐行推进。
    // 行内字符推进不产生亚行位移，避免吸附后看上去没有真正落位。
    final targetRow = snapshot.rowForChar(target, offset);
    final wasSnapping = _follower.snapping;
    _follower.snapTo(_targetForRow(targetRow));
    if (_follower.snapping && !wasSnapping) {
      _snapStartMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _prepareLayout(BuildContext context, BoxConstraints constraints) {
    final textScaler = MediaQuery.textScalerOf(context);
    _stageWidth = _settings.stageWidthFor(constraints.maxWidth);
    _stageLeft = _settings.stageLeftFor(constraints.maxWidth);
    _viewportW = constraints.maxWidth;
    _viewportH = constraints.maxHeight;

    final align = _settings.alignCenter ? TextAlign.center : TextAlign.left;
    final key = [
      _snapshotRevision,
      _stageWidth.toStringAsFixed(2),
      _settings.fontSize.toStringAsFixed(2),
      _settings.lineHeight.toStringAsFixed(3),
      _settings.fontWeight.toStringAsFixed(0),
      _settings.letterSpacing.toStringAsFixed(2),
      textScaler.scale(1.0).toStringAsFixed(3),
      align.name,
    ].join('|');

    if (_snapshot == null || key != _snapshotKey) {
      _snapshotKey = key;
      final style = _baseTextStyle();
      _snapshot = LayoutSnapshot.build(
        lines: _script.lines.map((line) => line.text).toList(growable: false),
        measurer: FlutterRowMeasurer(
          style: style,
          textScaler: textScaler,
          align: align,
        ),
        maxWidth: math.max(1, _stageWidth),
        rowPadY: _settings.rowPadYFor(_settings.fontSize),
        rowGap: _settings.rowGapFor(_settings.fontSize),
        fallbackTextHeight: _settings.fontSize * _settings.textStyleHeight,
        textRevision: _snapshotRevision,
      );
    }

    final snapshot = _snapshot!;
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top + 8;
    final panelReserve = math.min(96.0, _viewportH * 0.18);
    final safeBottom = math.max(safeTop + snapshot.rowHeight,
        _viewportH - media.padding.bottom - panelReserve);
    _band = ReadingBand(
      viewportHeight: _viewportH,
      safeTop: safeTop,
      safeBottom: safeBottom,
      bandRatio: _settings.readAheadRatio,
      rowHeight: snapshot.rowHeight,
      rowGap: snapshot.rowGap,
      prismDy: _settings.prismDy,
    );

    final band = _band!;
    final maxRow = math.max(0, snapshot.rowCount - 1);
    final min = math.min(
        0.0, band.targetForRowWithMirror(0, mirrorY: _settings.mirrorY));
    final max = math.max(
      min,
      band.targetForRowWithMirror(maxRow, mirrorY: _settings.mirrorY),
    );
    _follower
      ..snapDuration =
          ReadingFollower.snapDurationFromSmoothness(_settings.smoothness)
      ..configureBounds(min: min, max: max, pitch: snapshot.pitch);

    if (!_initialAnchorApplied && snapshot.rowCount > 0) {
      _initialAnchorApplied = true;
      _jumpFollowerToRow(
        snapshot.rowForChar(_anchor, _anchorChar),
        fade: false,
      );
    }
  }

  TextStyle _baseTextStyle() {
    return TextStyle(
      fontFamily: TpTokens.readerFontFamily,
      fontSize: _settings.fontSize,
      height: _settings.textStyleHeight,
      fontWeight: FontWeight
          .values[((_settings.fontWeight / 100).round() - 1).clamp(3, 8)],
      letterSpacing: _settings.letterSpacing,
      color: _palette.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _palette.background;
    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _prepareLayout(context, constraints);
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _locked,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onStageTap,
                    onLongPress: _lock,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_offset, _fade]),
                        child: _buildStage(),
                        builder: (context, child) => Transform(
                          transform: _viewportMatrix(
                            constraints.maxWidth,
                            constraints.maxHeight,
                            _offset.value,
                          ),
                          child: Opacity(opacity: _fade.value, child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildBandUnderline(),
              _buildBottomPanel(context),
              if (_voiceOn) _buildMicBadge(context),
              if (_locked) _buildLockBadge(),
              if (_panelHidden && !_locked) _buildPanelHandle(),
            ],
          );
        },
      ),
    );
  }

  Matrix4 _viewportMatrix(double width, double height, double position) {
    final matrix = Matrix4.identity();
    matrix.translateByDouble(
      _settings.prismDx * width,
      _settings.prismDy * height,
      0,
      1,
    );
    if (_settings.mirrorX) {
      matrix
        ..translateByDouble(width, 0, 0, 1)
        ..scaleByDouble(-1, 1, 1, 1);
    }
    if (_settings.mirrorY) {
      matrix
        ..translateByDouble(0, height, 0, 1)
        ..scaleByDouble(1, -1, 1, 1);
    }
    matrix.translateByDouble(0, -position, 0, 1);
    return matrix;
  }

  Widget _buildStage() {
    // 只在这些输入变化时重建正文；锚点跨行不再重建整篇
    // （当前行指示由屏幕空间的固定细线负责）。
    final key = '$_snapshotKey|${_settings.alignCenter}|'
        '${_settings.theme.name}|${_markersByLine.length}|'
        '${_band?.bandTop.toStringAsFixed(2) ?? ''}';
    final cached = _stageCache;
    if (cached != null && key == _stageCacheKey) return cached;
    final built = _buildStageUncached();
    _stageCache = built;
    _stageCacheKey = key;
    return built;
  }

  Widget _buildStageUncached() {
    final style = _baseTextStyle();
    final snapshot = _snapshot;
    final band = _band;
    return OverflowBox(
      alignment: Alignment.topLeft,
      // 必须放开宽度约束：默认会沿用父级的紧约束（全屏宽），
      // 导致左右边距对渲染无效，而测量却按窄画布算，行高也会错位。
      minWidth: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: SizedBox(
        width: _viewportW,
        child: Padding(
          // 左右边距可不等：画布按左缘偏移定位，右侧剩余空间补足。
          padding: EdgeInsets.only(
            left: _stageLeft,
            right: math.max(0, _viewportW - _stageLeft - _stageWidth),
          ),
          child: Column(
            key: const ValueKey('reader-stage'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: band?.bandTop ?? 0),
              if (snapshot != null)
                for (final row in snapshot.rows) _buildVisualRow(row, style),
            ],
          ),
        ),
      ),
    );
  }

  /// 视觉行：正文统一一种颜色，不用底色/左侧标记条/透明度渐变。
  ///
  /// 当前识别行由阅读带底部的固定细线指示（见 [_buildBandUnderline]），
  /// 这样滚动时不用重建整篇正文。
  Widget _buildVisualRow(VisualRow row, TextStyle style) {
    final textAlign =
        _settings.alignCenter ? TextAlign.center : TextAlign.start;
    final snapshot = _snapshot;

    return Container(
      height: row.height,
      margin: EdgeInsets.only(bottom: snapshot?.rowGap ?? 0),
      child: _buildRowText(row, style, textAlign),
    );
  }

  /// 阅读带底部的当前行指示线，固定在屏幕空间，随分数行滚动而不跳变。
  Widget _buildBandUnderline() {
    final snapshot = _snapshot;
    final band = _band;
    if (snapshot == null || band == null || snapshot.rowCount == 0) {
      return const SizedBox.shrink();
    }
    final left = _settings.prismDx * _viewportW +
        (_settings.mirrorX
            ? _viewportW - _stageLeft - _stageWidth
            : _stageLeft);
    return Positioned(
      left: left,
      top: band.bandTop + snapshot.rowHeight - 1.5,
      width: _stageWidth,
      height: 1.5,
      child: IgnorePointer(
        child: ColoredBox(
          color: _palette.highlightBar.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  /// 关键词/重点标记在视觉行内以底色显示（§4.4 L-07/L-08）。
  Widget _buildRowText(
    VisualRow row,
    TextStyle style,
    TextAlign textAlign,
  ) {
    final markers = _markersByLine[row.lineIndex];
    if (markers == null || markers.isEmpty) {
      return Text(
        row.text,
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }
    final line = _script.lines[row.lineIndex];
    final ranges = <(int, int)>[];
    for (final marker in markers) {
      if (marker.kind != MarkerKind.emphasis) continue;
      final start = marker.charOffset - line.sectionCharStart;
      if (start < 0) continue;
      final end = start + 10;
      final clippedStart = math.max(start, row.charStart);
      final clippedEnd = math.min(end, row.charEnd);
      if (clippedStart < clippedEnd) {
        ranges.add((clippedStart - row.charStart, clippedEnd - row.charStart));
      }
    }
    if (ranges.isEmpty) {
      return Text(
        row.text,
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = math.max(cursor, range.$1);
      if (start >= row.text.length) break;
      if (start > cursor) {
        spans.add(TextSpan(text: row.text.substring(cursor, start)));
      }
      final end = math.min(row.text.length, math.max(start, range.$2));
      spans.add(
        TextSpan(
          text: row.text.substring(start, end),
          style: style.copyWith(
            backgroundColor: _palette.highlightBar.withValues(alpha: 0.24),
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < row.text.length) {
      spans.add(TextSpan(text: row.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  // ---------------------------------------------------------------- 手势与面板

  void _resetPanelTimer() {
    _panelTimer?.cancel();
    // 暂停时让面板停留，方便连续调节；播放中 3 s 无操作自动淡出。
    if (_paused || _locked) return;
    _panelTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _locked || _dragging || _paused) return;
      if (_panelVisible) setState(() => _panelVisible = false);
    });
  }

  /// 手动隐藏优先于 3 s 自动淡出；隐藏时顶部栏与底部功能栏都不参与命中测试。
  bool get _chromeVisible => !_panelHidden && _panelVisible;

  void _keepPanel() {
    if (!_panelVisible) setState(() => _panelVisible = true);
    _resetPanelTimer();
  }

  Future<void> _hidePanel() async {
    _panelTimer?.cancel();
    if (!_panelHidden) {
      setState(() {
        _panelHidden = true;
        _panelVisible = false;
      });
      unawaited(HapticFeedback.selectionClick());
    }
    await saveReaderPanelHidden(_repository, true);
  }

  Future<void> _showPanel() async {
    if (!mounted) return;
    if (_panelHidden) {
      setState(() {
        _panelHidden = false;
        _panelVisible = true;
      });
      unawaited(HapticFeedback.selectionClick());
    }
    _resetPanelTimer();
    await saveReaderPanelHidden(_repository, false);
  }

  void _onStageTap() {
    if (_locked) return;
    // 单击 = 开始 / 暂停 / 继续，同时唤出控制面板（§4.3 C-04）。
    _keepPanel();
    if (!_started) {
      _start();
      return;
    }
    _togglePause();
  }

  void _onDragStart(DragStartDetails details) {
    if (_locked) return;
    _dragging = true;
    _follower.freeze();
    _keepPanel();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_locked || !_dragging) return;
    final dy = _settings.mirrorY ? -details.delta.dy : details.delta.dy;
    _follower.nudge(-dy);
    _offset.value = _follower.position;
    _syncAnchorFromPosition();
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _syncAnchorFromPosition();
    _tracker.forceLine(_anchor);
    _lineGate.reset();
    _earlyArm?.reset();
    _endRestMs = 0;
    if (!_paused) _follower.unfreeze();
    // 只有未自动滚动时才保留松手惯性；自动滚动模式直接从这个像素位置继续，
    // 不做整行吸附。
    if (!_started || _paused) {
      final velocity = details.primaryVelocity ?? 0;
      final dy = _settings.mirrorY ? velocity : -velocity;
      if (dy.abs() > 120) _follower.fling(dy);
    }
    _resetPanelTimer();
  }

  void _lock() {
    setState(() {
      _locked = true;
      _panelVisible = false;
    });
    _panelTimer?.cancel();
    _pushOverlayState();
    HapticFeedback.mediumImpact();
  }

  void _unlock() {
    setState(() => _locked = false);
    _keepPanel();
    _pushOverlayState();
  }

  /// 语音识别模式的常驻收音角标（Material 3 令牌）。
  ///
  /// 固定在顶部阅读预留区（正文锚点位于视口 35% 处），不覆盖当前行与高亮条。
  Widget _buildMicBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = resolveMicStatus(
      voiceOn: _voiceOn,
      ready: _voiceReady,
      paused: _paused,
      appResumed: _appResumed,
      degraded: _degraded,
      confidence: _confidence,
      health: _voiceHealth,
      gateStalled: _gateStalled,
    );
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
    final accent = status == MicStatusKind.listening
        ? _palette.highlightBar
        : _palette.dimText;
    return Positioned(
      top:
          MediaQuery.paddingOf(context).top + TpTokens.space6 + TpTokens.space8,
      left: TpTokens.space3,
      child: IgnorePointer(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: Material(
            color: _palette.controlSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(TpTokens.radiusXLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpTokens.space2,
                vertical: TpTokens.space1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: TpTokens.space1),
                  Text(
                    label,
                    style: TextStyle(
                      color: _palette.onControlSurface,
                      fontSize: TpTokens.readerSmallFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockBadge() {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      top: 48,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: _palette.controlSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(TpTokens.radiusXLarge),
          child: InkWell(
            borderRadius: BorderRadius.circular(TpTokens.radiusXLarge),
            onTap: _unlock,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpTokens.space4,
                vertical: TpTokens.space2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: _palette.highlightBar),
                  const SizedBox(width: TpTokens.space1),
                  Text(
                    l10n.readerLockedBadge,
                    style: TextStyle(
                      color: _palette.onControlSurface,
                      fontSize: TpTokens.readerSmallFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHandle() {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Semantics(
          button: true,
          label: l10n.readerShowPanel,
          child: Tooltip(
            message: l10n.readerShowPanel,
            child: Material(
              key: const ValueKey('reader-panel-handle'),
              color: _palette.controlSurface.withValues(alpha: 0.78),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(TpTokens.radiusXLarge),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(TpTokens.radiusXLarge),
                ),
                onTap: _showPanel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TpTokens.space1,
                    vertical: TpTokens.space3,
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: _palette.onControlSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 单栏顶部信息行：返回、标题、进度、设置与隐藏。
  Widget _buildBarHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.readerBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: _palette.onControlSurface),
        ),
        Expanded(
          child: Text(
            _script.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _palette.text,
              fontSize: TpTokens.readerTitleFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          l10n.readerProgress(
            _snapshot != null && _snapshot!.rowCount > 0
                ? _anchorRow + 1
                : _anchor + 1,
            _snapshot != null && _snapshot!.rowCount > 0
                ? _snapshot!.rowCount
                : _script.lines.length,
          ),
          style: TextStyle(
            color: _palette.dimText,
            fontSize: TpTokens.readerSmallFontSize,
          ),
        ),
        IconButton(
          tooltip: l10n.readerSettings,
          onPressed: _openSettings,
          icon: Icon(Icons.tune, color: _palette.onControlSurface),
        ),
        IconButton(
          tooltip: l10n.readerHidePanel,
          onPressed: _hidePanel,
          icon: Icon(Icons.visibility_off, color: _palette.onControlSurface),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1 : 0,
        duration: TpTokens.durationShort,
        child: IgnorePointer(
          ignoring: !_chromeVisible || _locked,
          child: Container(
            decoration: BoxDecoration(
              color: _palette.controlSurface.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: _palette.onControlSurface.withValues(
                    alpha: TpTokens.readerControlDividerOpacity,
                  ),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TpTokens.space3,
                  TpTokens.space2,
                  TpTokens.space3,
                  TpTokens.space2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBarHeader(context),
                    if (!_voiceOn && _finished) _buildFinishedNotice(),
                    if (_recordingOn) _buildRecordingStatus(),
                    if (_replayOn) _buildReplayBar(),
                    if (!_started)
                      Padding(
                        padding: const EdgeInsets.only(top: TpTokens.space1),
                        child: Text(
                          l10n.readerTapToStart,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _palette.dimText,
                            fontSize: TpTokens.readerSmallFontSize,
                          ),
                        ),
                      ),
                    if (_barActions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: TpTokens.space1),
                        child: _buildControls(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedNotice() {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('finished-status'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: TpTokens.space1),
      padding: const EdgeInsets.symmetric(
        horizontal: TpTokens.space3,
        vertical: TpTokens.space2,
      ),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
      ),
      child: Text(
        l10n.readerFinished,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _palette.text,
          fontSize: TpTokens.readerSmallFontSize,
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('recording-status'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: TpTokens.space1),
      padding: const EdgeInsets.symmetric(
        horizontal: TpTokens.space3,
        vertical: TpTokens.space1,
      ),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record,
              size: 14, color: Color(0xFFE5484D)),
          const SizedBox(width: TpTokens.space2),
          Text(
            l10n.recordElapsed(formatRecordingDuration(_recordElapsedMs)),
            style: TextStyle(
              color: _palette.onControlSurface,
              fontSize: TpTokens.readerSmallFontSize,
            ),
          ),
          const Spacer(),
          Text(
            l10n.recordRecordingHint,
            style: TextStyle(
              color: _palette.dimText,
              fontSize: TpTokens.readerCaptionFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayBar() {
    final l10n = AppLocalizations.of(context);
    final controller = _replay;
    final duration = controller?.durationMs ?? 0;
    final maxMs = duration <= 0 ? 1.0 : duration.toDouble();
    final positionMs =
        _replayPosition.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    return Container(
      key: const ValueKey('replay-bar'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: TpTokens.space1),
      padding: const EdgeInsets.symmetric(horizontal: TpTokens.space2),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _replayPlaying ? l10n.recordPause : l10n.recordPlay,
            onPressed: _toggleReplayPlay,
            icon: Icon(_replayPlaying ? Icons.pause : Icons.play_arrow),
            color: _palette.onControlSurface,
          ),
          Expanded(
            child: Slider(
              value: positionMs,
              max: maxMs,
              onChanged: _seekReplay,
            ),
          ),
          Text(
            '${formatRecordingDuration(positionMs.round())} / '
            '${formatRecordingDuration(duration)}',
            style: TextStyle(
              color: _palette.onControlSurface,
              fontSize: TpTokens.readerCaptionFontSize,
            ),
          ),
          PopupMenuButton<double>(
            tooltip: '${(controller?.speed ?? 1).toStringAsFixed(1)}x',
            initialValue: controller?.speed ?? 1,
            onSelected: _setReplaySpeed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: TpTokens.space2),
              child: Text(
                '${(controller?.speed ?? 1).toStringAsFixed(1)}x',
                style: TextStyle(
                  color: _palette.onControlSurface,
                  fontSize: TpTokens.readerSmallFontSize,
                ),
              ),
            ),
            itemBuilder: (context) => [
              for (final speed in ReplayController.speeds)
                PopupMenuItem<double>(
                  value: speed,
                  child: Text('${speed.toStringAsFixed(1)}x'),
                ),
            ],
          ),
          IconButton(
            tooltip: l10n.recordExitReplay,
            onPressed: _stopReplay,
            icon: const Icon(Icons.close),
            color: _palette.onControlSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TpTokens.space2,
      runSpacing: TpTokens.space1,
      children: [
        for (final action in _barActions) _buildBarAction(action),
        if (devAudioEnabled)
          IconButton(
            tooltip: l10n.readerReplayTooltip,
            onPressed: _startReplay,
            icon: Icon(Icons.graphic_eq, color: _palette.onControlSurface),
          ),
      ],
    );
  }

  /// 功能栏按钮：只渲染用户在设置里选中的项目。
  Widget _buildBarAction(ReaderBarAction action) {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case ReaderBarAction.prev:
        return IconButton(
          tooltip: l10n.readerPrevSentence,
          onPressed: () => _jumpLines(-1),
          icon: Icon(Icons.keyboard_arrow_up, color: _palette.onControlSurface),
        );
      case ReaderBarAction.next:
        return IconButton(
          tooltip: l10n.readerNextSentence,
          onPressed: () => _jumpLines(1),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _palette.onControlSurface,
          ),
        );
      case ReaderBarAction.playPause:
        return IconButton(
          tooltip: _paused
              ? (_started ? l10n.readerResume : l10n.readerStart)
              : l10n.readerPause,
          onPressed: _togglePause,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          color: _palette.onControlSurface,
        );
      case ReaderBarAction.speed:
        return _buildStepper(
          minusIcon: Icons.remove,
          plusIcon: Icons.add,
          label: l10n.readerLineRate(_settings.speed.toStringAsFixed(1)),
          onMinus: () => _adjustSpeed(-0.2),
          onPlus: () => _adjustSpeed(0.2),
        );
      case ReaderBarAction.fontSize:
        return _buildStepper(
          minusIcon: Icons.text_decrease,
          plusIcon: Icons.text_increase,
          label: '${_settings.fontSize.toInt()}',
          onMinus: () => _adjustFontSize(-4),
          onPlus: () => _adjustFontSize(4),
        );
      case ReaderBarAction.mic:
        return IconButton(
          tooltip: _voiceOn ? l10n.readerVoiceOn : l10n.readerVoiceOff,
          onPressed: _toggleMic,
          icon: Icon(_voiceOn ? Icons.mic : Icons.mic_none),
          color: _voiceOn ? _palette.highlightBar : _palette.onControlSurface,
          style: IconButton.styleFrom(
            backgroundColor:
                _voiceOn ? _palette.highlightBar.withValues(alpha: 0.16) : null,
          ),
        );
      case ReaderBarAction.restart:
        return IconButton(
          tooltip: l10n.readerRestart,
          onPressed: _restart,
          icon: Icon(Icons.replay, color: _palette.onControlSurface),
        );
      case ReaderBarAction.overlay:
        return IconButton(
          tooltip:
              _overlayOn ? l10n.overlayCloseTooltip : l10n.overlayOpenTooltip,
          onPressed: _toggleOverlay,
          icon: Icon(
            _overlayOn
                ? Icons.picture_in_picture_alt
                : Icons.picture_in_picture_alt_outlined,
          ),
          color: _overlayOn ? _palette.highlightBar : _palette.onControlSurface,
        );
      case ReaderBarAction.remote:
        return IconButton(
          tooltip: _remoteOn ? l10n.readerRemoteOn : l10n.readerRemoteOff,
          onPressed: _openRemote,
          icon: Icon(_remoteOn ? Icons.cast_connected : Icons.cast),
          color: _remoteOn ? _palette.highlightBar : _palette.onControlSurface,
        );
      case ReaderBarAction.display:
        return IconButton(
          tooltip: _displayOn ? l10n.readerExternalOn : l10n.readerExternalOff,
          onPressed: _openExternalDisplay,
          icon: Icon(
            _displayOn ? Icons.desktop_windows : Icons.desktop_windows_outlined,
          ),
          color: _displayOn ? _palette.highlightBar : _palette.onControlSurface,
        );
      case ReaderBarAction.record:
        return IconButton(
          tooltip: _recordingOn ? l10n.recordStop : l10n.recordStart,
          onPressed: _toggleRecord,
          icon: Icon(
            _recordingOn ? Icons.stop_circle : Icons.fiber_manual_record,
          ),
          color: _recordingOn
              ? const Color(0xFFE5484D)
              : _palette.onControlSurface,
        );
      case ReaderBarAction.history:
        return IconButton(
          tooltip: l10n.recordHistory,
          onPressed: _openRecordings,
          icon: Icon(Icons.history, color: _palette.onControlSurface),
        );
      case ReaderBarAction.lock:
        return IconButton(
          tooltip: l10n.readerLock,
          onPressed: _lock,
          icon: Icon(Icons.lock_outline, color: _palette.onControlSurface),
        );
    }
  }

  Widget _buildStepper({
    required IconData minusIcon,
    required IconData plusIcon,
    required String label,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
        color: _palette.onControlSurface.withValues(
          alpha: TpTokens.readerControlFillOpacity,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: Icon(minusIcon, size: 20),
            color: _palette.onControlSurface,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: TpTokens.readerStepperMinWidth,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _palette.onControlSurface,
                fontSize: TpTokens.readerSmallFontSize,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: Icon(plusIcon, size: 20),
            color: _palette.onControlSurface,
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    _keepPanel();
    if (!_started) {
      _start();
      return;
    }
    // 篇尾暂停后再点开始：按循环逻辑回到篇首。
    if (_finished) {
      _restartLoop();
      return;
    }
    setState(() => _paused = !_paused);
    if (_paused) {
      _follower.freeze();
    } else {
      _resetFollowState();
      _follower.unfreeze();
    }
    _resetPanelTimer();
    _pushOverlayState();
  }

  /// 首次开始：从起始状态进入运行态（手动滚动或语音跟随）。
  void _start() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _finished = false;
    _resetFollowState();
    setState(() {
      _started = true;
      _paused = false;
    });
    _follower.unfreeze();
    _resetPanelTimer();
    _pushOverlayState();
    AppLog.instance.event('reader', 'start', {
      'script': widget.document.id,
      'mode': _voiceOn ? 'voice' : 'manual',
    });
  }

  void _adjustSpeed(double delta) {
    _keepPanel();
    _applySettings(
      _settings.copyWith(
        speed: (_settings.speed + delta).clamp(0.2, 10.0).toDouble(),
      ),
    );
  }

  void _adjustFontSize(double delta) {
    _keepPanel();
    _applySettings(
      _settings.copyWith(
        fontSize: (_settings.fontSize + delta)
            .clamp(TpTokens.readerMinFontSize, TpTokens.readerMaxFontSize)
            .toDouble(),
      ),
    );
  }

  void _retargetAnchor() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return;
    _jumpFollowerToRow(
      snapshot.rowForChar(_anchor, _anchorChar),
      fade: false,
    );
  }

  void _jumpToLine(int line) => _jumpTo(line, 0);

  /// 跳转到语义行内的指定字符（复盘/旧锚点恢复使用）。
  void _jumpTo(int line, int charOffset) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return;
    final target = line.clamp(0, _script.lines.length - 1);
    final offset =
        charOffset.clamp(0, _script.lines[target].text.length).toInt();
    _loopTimer?.cancel();
    _loopTimer = null;
    _finished = false;
    _endRestMs = 0;
    _jumpFollowerToRow(snapshot.rowForChar(target, offset));
    _tracker.forceLine(target);
    _lineGate.reset();
    _earlyArm?.reset();
    _coverage.reset();
    _jumpBudget.reset();
    setState(() {
      _anchor = target;
      _anchorChar = offset;
    });
  }

  void _jumpLines(int delta) {
    _keepPanel();
    _jumpToLine(_anchor + delta);
  }

  void _restart() {
    _keepPanel();
    _jumpToLine(0);
    setState(() {
      _confidence = 0;
    });
  }

  // ------------------------------------------------------------ 录制与复盘

  Future<void> _toggleRecord() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    if (_recordingOn) {
      final controller = _recording;
      _recordUiTimer?.cancel();
      setState(() => _recordingOn = false);
      _session?.onAudioChunk = null;
      RecordingEntry? entry;
      try {
        entry = await controller?.stop();
      } catch (_) {
        entry = null;
      }
      if (!mounted) return;
      setState(() {
        _recording = null;
        _recordElapsedMs = 0;
      });
      _showError(entry == null ? l10n.recordSaveFailed : l10n.recordSaved);
      return;
    }

    if (_replayOn) await _stopReplay();
    final session = _voiceOn ? _session : null;
    final controller = RecordingController(
      repository: _repository,
      store: RecordingStore(),
      scriptId: widget.document.id,
      readAnchor: () => _anchor,
      readChar: () => _anchorChar,
      onError: (message) {
        if (mounted) _showError(message);
      },
    );
    try {
      // 语音跟随已开麦时复用同一条采集流，避免两路麦克风（§10.6）。
      await controller.start(useMic: session == null);
      if (!mounted) {
        await controller.cancel();
        return;
      }
      session?.onAudioChunk = controller.feed;
      setState(() {
        _recording = controller;
        _recordingOn = true;
        _recordElapsedMs = 0;
      });
      _recordUiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || !_recordingOn || _recording != controller) return;
        setState(() => _recordElapsedMs = controller.elapsedMs);
      });
      AppLog.instance.event('record', 'start', {
        'script': widget.document.id,
        'sharedMic': session != null,
      });
    } on AudioCaptureException catch (_) {
      if (mounted) _showError(l10n.recordPermissionDenied);
    } catch (_) {
      if (mounted) _showError(l10n.recordSaveFailed);
    }
  }

  Future<void> _openRecordings() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    final entries = await _repository.recordingsForScript(widget.document.id);
    if (!mounted) return;
    await showRecordingHistorySheet(
      context: context,
      entries: entries,
      onReplay: (entry) => unawaited(_startReplayEntry(entry)),
      onExport: _exportRecording,
      onDelete: (entry) async {
        try {
          await _repository.deleteRecording(entry.id);
        } catch (_) {
          if (mounted) _showError(l10n.recordDeleteFailed);
        }
        return _repository.recordingsForScript(widget.document.id);
      },
    );
    if (!mounted) return;
    _keepPanel();
  }

  /// 旧录制（时间轴 v1）的行号是"按句切行"坐标，回放/导出前折算到当前模型。
  RecordingTimeline _migratedTimeline(RecordingEntry entry) {
    final timeline = ReplayController.timelineOf(entry);
    if (timeline.version >= 2) return timeline;
    final samples = <TimelineSample>[];
    for (final sample in timeline.samples) {
      final mapped = mapLegacyAnchorToParagraphs(
        sections: widget.document.sections,
        lines: _script.lines,
        legacyAnchor: sample.anchor,
      );
      samples.add(
        TimelineSample(
          t: sample.t,
          anchor: mapped.line,
          char: mapped.charOffset,
          conf: sample.conf,
        ),
      );
    }
    return RecordingTimeline(
      scriptId: timeline.scriptId,
      durationMs: timeline.durationMs,
      samples: samples,
    );
  }

  Future<void> _exportRecording(RecordingEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final lines =
        _script.lines.map((line) => line.text).toList(growable: false);
    final snapshot = _snapshot;
    final rows = _visualLines;
    try {
      final count = await exportRecording(
        entry: entry,
        lines: lines,
        timeline: _migratedTimeline(entry),
        captionLines: rows.isEmpty ? null : rows,
        captionIndex: snapshot == null || rows.isEmpty
            ? null
            : (line, charOffset) => snapshot.rowForChar(line, charOffset),
      );
      if (!mounted || count == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recordExportDone(count))),
      );
    } catch (_) {
      if (!mounted) return;
      _showError(l10n.recordExportFailed);
    }
  }

  Future<void> _startReplayEntry(RecordingEntry entry) async {
    final l10n = AppLocalizations.of(context);
    await _stopReplay();
    if (_voiceOn) await _stopVoice();
    if (!_paused) setState(() => _paused = true);
    _follower.freeze();

    final controller = ReplayController(
      entry: entry,
      timeline: _migratedTimeline(entry),
      onPosition: (position) {
        if (mounted) setState(() => _replayPosition = position);
      },
      onPlayingChanged: (playing) {
        if (mounted) setState(() => _replayPlaying = playing);
      },
      onAnchor: (line, charOffset) {
        if (mounted) _jumpTo(line, charOffset);
      },
      onError: (message) {
        if (mounted) _showError(message);
      },
    );
    final ok = await controller.start();
    if (!mounted || !ok) {
      await controller.dispose();
      if (mounted && !ok) _showError(l10n.recordReplayFailed);
      return;
    }
    setState(() {
      _replay = controller;
      _replayOn = true;
      _replayPlaying = true;
      _replayPosition = Duration.zero;
    });
    AppLog.instance.event('record', 'replay_start', {
      'script': widget.document.id,
      'durationMs': entry.durationMs,
    });
  }

  Future<void> _toggleReplayPlay() async {
    final controller = _replay;
    if (controller == null) return;
    await controller.toggle();
    if (!mounted) return;
    setState(() => _replayPlaying = controller.isPlaying);
  }

  void _seekReplay(double value) {
    unawaited(_replay?.seek(Duration(milliseconds: value.round())));
  }

  Future<void> _setReplaySpeed(double speed) async {
    await _replay?.setSpeed(speed);
    if (mounted) setState(() {});
  }

  Future<void> _stopReplay() async {
    final controller = _replay;
    if (controller == null) return;
    setState(() {
      _replay = null;
      _replayOn = false;
      _replayPlaying = false;
      _replayPosition = Duration.zero;
    });
    await controller.dispose();
  }

  Future<void> _openSettings() async {
    _keepPanel();
    await showReaderSettingsSheet(
      context: context,
      settings: _settings,
      onChanged: _applySettings,
      overlaySettings: _overlaySettings,
      onOverlayChanged: _applyOverlaySettings,
      onSaveAsDefault: (settings) async {
        await saveGlobalReaderDefaults(_repository, settings);
        AppLog.instance.event('reader', 'settings_saved_as_default', {
          'script': widget.document.id,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).readerSavedAsDefault)),
        );
      },
    );
    if (!mounted) return;
    _keepPanel();
  }

  Future<void> _toggleMic() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    if (_voiceOn) {
      await _stopVoice();
      return;
    }
    if (_recordingOn) {
      _showError(l10n.recordInProgress);
      return;
    }
    await _ensureNotificationPermission();
    final lab = await loadAsrLabSettings(_repository);
    if (!mounted) return;
    final session = VoiceFollowSession(
      index: _index,
      tracker: _tracker,
      l10n: l10n,
      profile: MatchProfile.of(_settings.matchTolerance),
      tuning: lab.toAsrTuning(),
      audioConfig: lab.toAudioConfig(),
      modelSpec: _settings.asrModel.spec,
      onUpdate: _onVoiceUpdate,
      onError: _showError,
      onHealth: _onVoiceHealth,
    );
    _session = session;
    _loopTimer?.cancel();
    _loopTimer = null;
    _finished = false;
    _endRestMs = 0;
    _tracker.reset();
    _tracker.forceLine(_anchor);
    _lineGate.reset();
    _earlyArm?.reset();
    setState(() {
      _voiceOn = true;
      _started = true;
      _paused = false;
      _voiceReady = false;
      _lastVoiceAtMs = DateTime.now().millisecondsSinceEpoch;
      _confidence = 0;
      _degraded = false;
      _voiceHealth = VoiceHealthKind.idle;
      _gateStalled = false;
      _anchorSeen = _anchor;
      _lastAnchorAdvanceMs = DateTime.now().millisecondsSinceEpoch;
    });
    _follower.unfreeze();
    _pushOverlayState();
    AppLog.instance.event('voice', 'mic_start', {
      'script': widget.document.id,
      ...lab.toJson(),
    });
    try {
      await session.startMic();
      await PlatformBridge.startVoiceService();
      if (_recordingOn) session.onAudioChunk = _recording?.feed;
      if (mounted) {
        setState(() {
          _voiceReady = true;
          _lastVoiceAtMs = DateTime.now().millisecondsSinceEpoch;
        });
        _pushOverlayState();
      }
    } catch (error) {
      await _stopVoice();
      // 解包失败与麦克风失败分开提示：前者可在同一入口重试，并如实说明半成品是否已清理。
      _showError(
        error is ModelInstallException
            ? (error.cleaned
                ? l10n.readerModelInstallFailed
                : l10n.readerModelInstallFailedUnclean)
            : l10n.readerMicStartFailed('$error'),
        onRetry: _toggleMic,
      );
    }
  }

  Future<void> _startReplay() async {
    _keepPanel();
    final l10n = AppLocalizations.of(context);
    if (_recordingOn) {
      _showError(l10n.recordInProgress);
      return;
    }
    if (_replayOn) await _stopReplay();
    if (_voiceOn) {
      await _stopVoice();
    }
    final lab = await loadAsrLabSettings(_repository);
    if (!mounted) return;
    final session = VoiceFollowSession(
      index: _index,
      tracker: _tracker,
      l10n: l10n,
      profile: MatchProfile.of(_settings.matchTolerance),
      tuning: lab.toAsrTuning(),
      modelSpec: _settings.asrModel.spec,
      onUpdate: _onVoiceUpdate,
      onError: _showError,
      onHealth: _onVoiceHealth,
    );
    _session = session;
    _loopTimer?.cancel();
    _loopTimer = null;
    _finished = false;
    _endRestMs = 0;
    _tracker.reset();
    _tracker.forceLine(_anchor);
    _lineGate.reset();
    _earlyArm?.reset();
    setState(() {
      _voiceOn = true;
      _started = true;
      _paused = false;
      _voiceReady = false;
      _lastVoiceAtMs = DateTime.now().millisecondsSinceEpoch;
      _confidence = 0;
      _degraded = false;
      _voiceHealth = VoiceHealthKind.idle;
      _gateStalled = false;
      _anchorSeen = _anchor;
      _lastAnchorAdvanceMs = DateTime.now().millisecondsSinceEpoch;
    });
    _follower.unfreeze();
    _pushOverlayState();
    AppLog.instance.event('voice', 'replay_start', {
      'script': widget.document.id,
      ...lab.toJson(),
    });
    try {
      await session.startReplay('assets/test_wavs/demo_zh.wav');
      if (mounted) {
        setState(() {
          _voiceReady = true;
          _lastVoiceAtMs = DateTime.now().millisecondsSinceEpoch;
        });
        _pushOverlayState();
      }
    } catch (error) {
      await _stopVoice();
      _showError(
        error is ModelInstallException
            ? (error.cleaned
                ? l10n.readerModelInstallFailed
                : l10n.readerModelInstallFailedUnclean)
            : l10n.readerReplayStartFailed('$error'),
        onRetry: _startReplay,
      );
    }
  }

  Future<void> _stopVoice() async {
    final session = _session;
    _session = null;
    _loopTimer?.cancel();
    _loopTimer = null;
    _finished = false;
    _endRestMs = 0;
    if (mounted) {
      setState(() {
        _voiceOn = false;
        _voiceReady = false;
        _paused = true;
        _confidence = 0;
        _degraded = false;
        _voiceHealth = VoiceHealthKind.idle;
        _gateStalled = false;
      });
      _pushOverlayState();
    }
    _lineGate.reset();
    _follower.freeze();
    await session?.dispose();
    await PlatformBridge.stopVoiceService();
    if (_recordingOn) await _toggleRecord();
    _tracker.reset();
    AppLog.instance.event('voice', 'stopped', {
      'script': widget.document.id,
    });
  }

  /// 会话每秒评估的健康度变化：角标按真实原因切换文案（日志在会话内写）。
  void _onVoiceHealth(VoiceHealth health) {
    if (!mounted || _voiceHealth == health.kind) return;
    setState(() => _voiceHealth = health.kind);
    _pushOverlayState();
  }

  void _onVoiceUpdate(VoiceFollowUpdate update) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastVoiceAtMs = now;
    // 把当前阅读位置回填给对齐器：下一条识别文本从该位置起算窗口，
    // 避免长文本/端点重置后锚点被拉回行首。
    _session?.anchorCharHint = _anchorChar;
    _session?.anchorCharLine = _anchor;
    final matched = update.align.matched;
    // 连续朗读 → 闸门自适应放宽；退出条件由 monitor 在静音/低置信时回收。
    // 未命中/等待不是「低置信证据」，不能喂给 monitor，否则会误退出放宽态。
    if (matched) {
      _speechMonitor.onUpdate(
        at: DateTime.fromMillisecondsSinceEpoch(now),
        confidence: update.align.confidence,
        line: update.tracker.line,
      );
    }
    _applyAdaptiveGate(now);
    _updateLatencyEstimate(update.asr.decodeMs, now);
    if (now - _lastFollowLogMs >= 2000) {
      _lastFollowLogMs = now;
      AppLog.instance.event('voice', 'follow_update', {
        'line': update.tracker.line,
        'confidence': _round(update.tracker.confidence),
        'degraded': update.tracker.degraded,
        'decodeMs': _round(update.asr.decodeMs),
        'matched': matched,
        'pending': update.align.pending,
      });
    }
    final candidate = update.tracker.line
        .clamp(0, math.max(0, _script.lines.length - 1))
        .toInt();
    final alignLine = update.align.anchorLine
        .clamp(0, math.max(0, _script.lines.length - 1))
        .toInt();
    final alignChar =
        update.align.anchorCharOffset < 0 ? 0 : update.align.anchorCharOffset;
    // 临时诊断（仅 debug 取证用）：每次识别更新的对齐结果原文与分数。
    // 临时诊断（仅 debug 取证用）：只记计数/行号/置信度，识别原文不入日志
    // （CODING §7）。
    AppLog.instance.event('diag', 'voice', {
      'matched': matched,
      'conf': _round(update.align.confidence),
      'line': update.align.anchorLine,
      'cand': update.tracker.line,
      'span': update.align.spanLength,
      'cost': _round(update.align.spanCost),
      'pending': update.align.pending,
      'suggested': update.align.suggestedLine,
      'anchor': _anchor,
      'final': update.asr.isFinal,
      'started': _started,
      'paused': _paused,
    });
    // 展示与跟随解耦：无论是否对齐成功，置信度与心跳都照常刷新，
    // 对不上台本时只冻结滚行。
    setState(() {
      _confidence = update.tracker.confidence;
      _degraded = update.tracker.degraded;
    });
    if (!matched) {
      _logAlignBlocked(update, now);
      return;
    }
    // 未开始或已暂停：只更新状态，不推进锚点（§4.3 C-04 起始态）。
    if (!_started || _paused) return;
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return;

    // 失败重定位：对齐器已保证落点 ≤ 当前行 +3、只前进、超限只给建议行。
    // 这里再按证据强度夹一次，确保短跨度/次高置信不能一次跨多行。
    if (update.align.reanchored) {
      final target = math.min(
        alignLine,
        _anchor +
            leapCapForEvidence(
              spanLength: update.align.spanLength,
              confidence: update.align.confidence,
            ),
      );
      AppLog.instance.event('voice', 'align_reanchor', {
        'from': _anchor,
        'to': target,
        'confidence': _round(update.align.confidence),
      });
      _lineGate.reset();
      _coverage.reset();
      _earlyArm?.reset();
      _advanceTo(target, target == alignLine ? alignChar : 0);
      return;
    }

    if (_settings.lineStepFollow) {
      final spoken = const Normalizer().normalize(update.partial);
      // 同一行内：字符级锚点只用于滚动位置/坐标，不作为跨行放行条件。
      if (alignLine == _anchor) {
        if (alignChar > _anchorChar) {
          _advanceTo(_anchor, alignChar);
        }
        // 行级覆盖只在行内记账，不在行内滚行：句末停顿里滚行属于抢行。
        _coverage.update(_anchor, spoken);
        return;
      }
      // 行级覆盖率放行：整行覆盖达标就不再要求逐字连续命中/弱命中累计。
      //
      // 前置条件是「对齐已跨到别的行」（说明音频里已经有下一行的读音），
      // 因此不会在句末静音里靠累积覆盖提前滚行（静音守线）。
      final cover = _coverage.update(_anchor, spoken);
      final weakConfidence =
          MatchProfile.of(_settings.matchTolerance).weakConfidence;
      if (_anchor + 1 < _script.lines.length &&
          update.align.confidence >= weakConfidence &&
          _coverage.allowsAdvance(cover)) {
        final target = math.min(
          alignLine,
          _anchor +
              leapCapForEvidence(
                spanLength: update.align.spanLength,
                confidence: update.align.confidence,
              ),
        );
        AppLog.instance.event('voice', 'line_coverage', {
          'from': _anchor,
          'to': target,
          'ratio': _round(cover.ratio),
          'farthest': _round(cover.farthestRatio),
        });
        _advanceTo(target, target == alignLine ? alignChar : 0);
        return;
      }
      final decision = _lineGate.evaluate(
        currentLine: _anchor,
        candidateLine: candidate,
        confidence: update.align.confidence,
        isFinal: update.asr.isFinal,
        spanLength: update.align.spanLength,
      );
      AppLog.instance.event('diag', 'gate', {
        'from': _anchor,
        'aline': alignLine,
        'cover': _round(cover.ratio),
        'far': _round(cover.farthestRatio),
        'allows': _coverage.allowsAdvance(cover),
        'weak': _round(weakConfidence),
        'conf': _round(update.align.confidence),
        'advanced': decision.advanced,
        'waiting': decision.waiting,
        'low': decision.lowConfidence,
        'leap': decision.leap,
      });
      if (!decision.advanced) {
        // 闸门未推进时，检查下一行前缀能否提前跨行（严格档自动关闭）。
        // 低置信不触发：否则等于绕过闸门用两个尾字抢行。
        final arm = update.align.confidence < weakConfidence
            ? null
            : _earlyArm?.evaluate(
                currentLine: _anchor,
                anchorToken: update.align.anchorToken,
                spoken: spoken,
                isFinal: update.asr.isFinal,
              );
        if (arm != null && arm.armed) {
          AppLog.instance.event('voice', 'early_arm', {
            'from': _anchor,
            'to': arm.line,
            'confidence': _round(update.align.confidence),
          });
          _advanceTo(arm.line, 0);
        }
        return;
      }
      _advanceTo(
        decision.line,
        decision.line == alignLine ? alignChar : 0,
      );
      return;
    }

    // 平滑模式：每次更新都连续逼近对齐位置（含段内字符），但只向前。
    if (alignLine > _anchor) {
      _advanceTo(alignLine, alignChar);
    } else if (alignLine == _anchor && alignChar > _anchorChar) {
      _advanceTo(_anchor, alignChar);
    }
  }

  /// 重锚发现远超 +3 行的候选：只记日志，不移动阅读位置。
  void _logAlignBlocked(VoiceFollowUpdate update, int now) {
    final suggested = update.align.suggestedLine;
    if (suggested < 0) return;
    if (now - _lastAlignBlockedLogMs < 2000) return;
    _lastAlignBlockedLogMs = now;
    AppLog.instance.event('voice', 'align_blocked', {
      'from': _anchor,
      'suggested': suggested,
      'confidence': _round(update.align.confidence),
    });
  }

  /// 把连续朗读检测结果同步到闸门；状态翻转写一次日志便于对照。
  void _applyAdaptiveGate(int nowMs) {
    final relaxed = _speechMonitor.relaxed;
    if (relaxed == _lineGate.relaxed) return;
    _lineGate.relaxed = relaxed;
    if (nowMs - _lastGateModeLogMs < 1000) return;
    _lastGateModeLogMs = nowMs;
    AppLog.instance.event('voice', 'adapt_gate', {
      'relaxed': relaxed,
      'confirm': _lineGate.effectiveConfirm,
      'weak': _lineGate.effectiveWeak,
      'weakHits': _lineGate.effectiveWeakHits,
    });
    if (mounted) setState(() {});
  }

  /// 端到端延迟估计：采集分片 + 解码到出文 + 一帧渲染。
  ///
  /// 分片与解码取实测（`decodeMs` 来自识别引擎），一帧按 60 fps 估算；
  /// 用 EMA 平滑后按最近语速折算成「提前行数」，供滚动目标前馈。
  void _updateLatencyEstimate(double decodeMs, int nowMs) {
    // 采集分片取真机实际大小（日志 1280 samples @16k = 80 ms），
    // 不再硬编码 40 ms；未知时回落到 40 ms。
    final chunkMs = (_session?.chunkMs ?? 40).toDouble();
    const frameMs = 16.7;
    final sample = chunkMs + decodeMs + frameMs;
    _latencyEstimateMs = _latencyEstimateMs == 0
        ? sample
        : _latencyEstimateMs * 0.8 + sample * 0.2;

    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rowCount == 0) return;
    final row = snapshot.rowForChar(_anchor, _anchorChar);
    if (_lastVoiceRow >= 0 && row > _lastVoiceRow && _lastVoiceRowAtMs > 0) {
      final seconds = (nowMs - _lastVoiceRowAtMs) / 1000.0;
      if (seconds >= 0.2 && seconds <= 5.0) {
        final rate = ((row - _lastVoiceRow) / seconds).clamp(0.0, 4.0);
        _rowsPerSecond = _rowsPerSecond * 0.7 + rate * 0.3;
      }
    }
    _lastVoiceRow = row;
    _lastVoiceRowAtMs = nowMs;

    if (nowMs - _lastLatencyLogMs >= 5000) {
      _lastLatencyLogMs = nowMs;
      AppLog.instance.event('voice', 'latency_compensation', {
        'enabled': _settings.latencyCompensation,
        'estimateMs': _round(_latencyEstimateMs),
        'rowsPerSecond': _round(_rowsPerSecond),
        'leadRows': _round(_compensationRows),
      });
    }
  }

  /// 前馈行数：延迟 × 语速，最多提前 0.8 行（不跨过下一行，避免抢行）。
  double get _compensationRows {
    if (!_settings.latencyCompensation) return 0;
    final rows = _latencyEstimateMs / 1000.0 * _rowsPerSecond;
    return rows.clamp(0.0, 0.8).toDouble();
  }

  void _resetLatencyCompensation() {
    _latencyEstimateMs = 0;
    _rowsPerSecond = 0.8;
    _lastVoiceRow = -1;
    _lastVoiceRowAtMs = 0;
    _lastLatencyLogMs = 0;
  }

  /// 语音卡住的第四类原因：识别文本一直在更新，但锚点不推进（不匹配）。
  ///
  /// 采集断流、引擎无帧、静音由 [VoiceHealthMonitor] 区分；这里只处理
  /// 「闸门收下了文本却没有前进」，且必须与静音互斥。
  void _updateGateStall() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 静音/断流时立刻退出连续朗读放宽态（不必等下一次识别输出）。
    _speechMonitor.tick(DateTime.fromMillisecondsSinceEpoch(now));
    _applyAdaptiveGate(now);
    if (_anchor != _anchorSeen) {
      _anchorSeen = _anchor;
      _lastAnchorAdvanceMs = now;
    }
    final stalled = _voiceReady &&
        !_paused &&
        _lastVoiceAtMs > 0 &&
        now - _lastVoiceAtMs < 2500 &&
        _lastAnchorAdvanceMs > 0 &&
        now - _lastAnchorAdvanceMs > 6000;
    if (stalled != _gateStalled && mounted) {
      setState(() => _gateStalled = stalled);
      if (stalled) {
        AppLog.instance.event('voice', 'gate_stalled', {
          'line': _anchor,
          'confidence': _round(_confidence),
          'sinceAdvanceMs': now - _lastAnchorAdvanceMs,
        });
      }
    }
  }

  void _showError(String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: AppLocalizations.of(context).actionRetry,
                onPressed: onRetry,
              ),
      ),
    );
  }
}
