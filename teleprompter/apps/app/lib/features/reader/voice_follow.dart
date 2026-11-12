import 'dart:async';
import 'dart:typed_data';

import 'package:asr_kit/asr_kit.dart';
import 'package:core_alignment/core_alignment.dart';

import '../../data/app_log.dart';
import '../../l10n/generated/app_localizations.dart';
import 'voice_health.dart';

class VoiceFollowUpdate {
  const VoiceFollowUpdate({
    required this.tracker,
    required this.align,
    required this.partial,
    required this.asr,
  });

  final TrackerUpdate tracker;
  final AlignResult align;
  final String partial;
  final AsrUpdate asr;
}

/// 模型准备函数（默认走 [ModelInstaller.ensure]，测试可注入）。
typedef ModelInstallFn = Future<InstalledAsrModel> Function(
  AsrModelSpec spec, {
  void Function()? onStart,
  void Function(ModelInstallProgress progress)? onProgress,
});

/// 把"流式识别 → 归一化对齐 → 锚点跟踪"串成最小闭环。
class VoiceFollowSession {
  VoiceFollowSession({
    required this.index,
    required this.tracker,
    required this.l10n,
    required this.onUpdate,
    this.onStatus,
    required this.onError,
    MatchProfile profile = MatchProfile.standardProfile,
    AsrTuning tuning = AsrTuning.defaults,
    AudioCaptureConfig audioConfig = AudioCaptureConfig.defaults,
    AsrModelSpec modelSpec = AsrModelSpec.zh14mInt8,
    ModelInstallFn? installModel,
    this.onHealth,
  })  : _profile = profile,
        _tuning = tuning,
        _audioConfig = audioConfig,
        _modelSpec = modelSpec,
        _installModel = installModel ?? ModelInstaller.ensure,
        _aligner = AlignEngine(
          index,
          lookAheadLines: profile.lookAheadLines,
          minScore: profile.weakConfidence,
        );

  /// 当前台本索引（重排后可整体替换）。
  ScriptIndex index;

  /// 当前锚点跟踪器（重排后随行数重建）。
  AlignTracker tracker;

  final AppLocalizations l10n;
  final void Function(VoiceFollowUpdate update) onUpdate;

  /// 过程状态回调：阅读页已改为极简健康角标，不再展示过程文案，可为空。
  final void Function(String status)? onStatus;
  final void Function(String message) onError;

  /// 健康度变化回调：阅读页据此展示与「未收音」区分开的角标文案。
  final void Function(VoiceHealth health)? onHealth;

  void _status(String text) => onStatus?.call(text);

  final MatchProfile _profile;
  final AsrTuning _tuning;
  final AudioCaptureConfig _audioConfig;
  final AsrModelSpec _modelSpec;
  final ModelInstallFn _installModel;
  AlignEngine _aligner;

  /// 最近一次对齐索引热替换耗时（阶段 B 验收用）。
  Duration lastAlignRestart = Duration.zero;

  /// 本次启动使用的随包模型（启动路径与回归用例共用）。
  AsrModelSpec get modelSpec => _modelSpec;
  SherpaAsrEngine _engine = SherpaAsrEngine();
  InstalledAsrModel? _installedModel;
  final AudioCapture _audio = AudioCapture();

  StreamSubscription<AsrUpdate>? _asrSub;
  StreamSubscription<AsrTick>? _tickSub;
  StreamSubscription<Float32List>? _audioSub;
  final Stopwatch _clock = Stopwatch();
  bool _disposed = false;

  /// 健康度判定与自愈：仅麦克风路径开启采集看门狗，回放不重开采集。
  final VoiceHealthMonitor _health = VoiceHealthMonitor();
  Timer? _watchdog;
  bool _micActive = false;
  bool _restartingCapture = false;
  bool _reportedCaptureError = false;
  int _restartAttempts = 0;
  DateTime? _lastRestartAt;
  bool _restartingEngine = false;
  int _engineRestartAttempts = 0;
  DateTime? _lastEngineRestartAt;
  VoiceHealthKind _lastHealthKind = VoiceHealthKind.idle;

  /// 录制与语音跟随共用同一条麦克风流（§10.6）：阅读页把分片转给录制器。
  void Function(Float32List chunk)? onAudioChunk;

  /// 重排后整体替换对齐索引与跟踪器。
  ///
  /// 只替换纯 Dart 的对齐对象，不重开麦克风、不重建 ASR 引擎，
  /// 因此录音分片与识别流保持连续（阶段 B：先保证不断，阶段 C 再做增量热换）。
  void restartWith({
    required ScriptIndex index,
    required AlignTracker tracker,
  }) {
    final watch = Stopwatch()..start();
    this.index = index;
    this.tracker = tracker;
    _aligner = AlignEngine(
      index,
      lookAheadLines: _profile.lookAheadLines,
      minScore: _profile.weakConfidence,
    );
    watch.stop();
    lastAlignRestart = watch.elapsed;
  }

  Future<void> startMic() async {
    await _prepare();
    _status(l10n.voiceRequestingMic);
    _micActive = true;
    _clock
      ..reset()
      ..start();
    _health.start(DateTime.now());
    await _listenCapture();
    _status(l10n.voiceFollowingMic);
    _startWatchdog();
  }

  /// 打开麦克风并把分片接到识别引擎。
  Future<void> _listenCapture() async {
    final stream = await _audio
        .start(config: _audioConfig)
        .timeout(const Duration(seconds: 5));
    _audioSub = stream.listen(
      (chunk) {
        _health.onChunk(DateTime.now());
        onAudioChunk?.call(chunk);
        _logChunkSize(chunk.length);
        _engine.accept(chunk);
      },
      onError: (Object error) {
        _health.onCaptureClosed();
        AppLog.instance.event('voice', 'capture_error', {'error': '$error'});
        if (!_reportedCaptureError) {
          _reportedCaptureError = true;
          onError(l10n.voiceAudioError('$error'));
        }
      },
      onDone: () {
        // 前台服务被杀 / 音频焦点被抢时插件会关流：交给看门狗自动重开。
        _health.onCaptureClosed();
        AppLog.instance.event('voice', 'capture_closed');
      },
    );
  }

  Future<void> startReplay(String assetPath) async {
    await _prepare();
    final wav = await PcmWav.fromAsset(assetPath);
    _micActive = false;
    _clock
      ..reset()
      ..start();
    _health.start(DateTime.now());
    _status(
      l10n.voiceReplayStatus(wav.durationSeconds.toStringAsFixed(1)),
    );
    _audioSub = WavReplaySource(wav).play().listen(
      (chunk) {
        _health.onChunk(DateTime.now());
        _engine.accept(chunk);
      },
      onDone: () {
        _status(l10n.voiceReplayDone);
        unawaited(_finishWithTail());
      },
      onError: (Object error) => onError(l10n.voiceReplayFailed('$error')),
    );
    _startWatchdog();
  }

  /// 音频结束后的收尾：先补一段尾音静音，再让引擎 flush 出 final。
  ///
  /// 直接 `finish()` 会把「最后不足一帧」的音节留在解码器里，实测结尾
  /// 「谢谢大家」这类短句会整句丢失。补 600 ms 静音后再结束输入，等价于
  /// 给端点检测留出尾音窗口。
  ///
  /// 只在回放（音频有明确终点）路径使用；麦克风实时路径不做强制 final，
  /// 避免把句中的自然停顿误判成句末。
  ///
  /// `never-inline`：回放收尾只在真机/发布包审计时按符号核对，内联会让
  /// `libapp.so` 里查不到该方法，无法确认尾音补偿确实进包。
  @pragma('vm:never-inline')
  Future<void> _finishWithTail({int tailMs = 600}) async {
    final silence = Float32List(1280); // 80 ms @ 16 kHz
    final chunks = (tailMs / 80).round();
    for (var i = 0; i < chunks; i++) {
      if (_disposed) return;
      _engine.accept(silence);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await _engine.finish();
  }

  Future<void> _prepare() async {
    final installWatch = Stopwatch()..start();
    // 解包与加载是两个阶段：解包按真实写盘进度推进，加载单独提示，避免被当成卡死。
    final model = await _installModel(
      _modelSpec,
      onStart: () => _status(l10n.voiceInstallModel),
      onProgress: (progress) => _status(
        l10n.voiceInstallModelProgress(
          progress.percent,
          progress.doneMb,
          progress.totalMb,
        ),
      ),
    );
    if (model.freshlyInstalled) {
      AppLog.instance.event('asr', 'installed', {
        'model': _modelSpec.id,
        'ms': installWatch.elapsedMilliseconds,
      });
    }
    _status(l10n.voiceLoadingRecognizer);
    _installedModel = model;
    await _engine.start(model, tuning: _tuning);
    _bindEngineStreams();
    _status(l10n.voiceReady(_engine.loadMs.toStringAsFixed(0)));
    AppLog.instance.event('asr', 'ready', {
      'loadMs': _engine.loadMs.round(),
    });
  }

  /// 把当前引擎的更新/心跳流接到会话上；引擎重建后复用同一套订阅逻辑。
  void _bindEngineStreams() {
    _asrSub = _engine.updates.listen(
      _onAsrUpdate,
      onError: (Object error) {
        onError(l10n.voiceRecognitionFailed('$error'));
        if (_micActive) unawaited(_restartEngine('stream_error'));
      },
    );
    _tickSub = _engine.ticks.listen((tick) {
      _health.onTick(DateTime.now());
      _logAsrLag(tick);
    });
  }

  /// 当前锚点行内的字符偏移（阅读位置），由阅读页在每次更新后回填。
  ///
  /// 对齐窗口从该位置起算，避免长文本按端点重置后锚点被拉回行首。
  int anchorCharHint = 0;

  /// [anchorCharHint] 所属的行。
  ///
  /// 跟踪器的行号可能先于阅读位置前进；此时旧偏移对当前行没有意义，
  /// 若照常传入会把对齐窗口整体推到下一行，形成低置信连锁前跳。
  int anchorCharLine = -1;

  int _lastLagLogMs = 0;
  double _lastTickAudioMs = 0;
  double _lastTickDecodeMs = 0;
  int _lastChunkSamples = 0;

  /// 当前采集分片时长（ms），供延迟估计使用；未知时按 40 ms 兜底。
  int get chunkMs =>
      _lastChunkSamples <= 0 ? 40 : (_lastChunkSamples * 1000 / 16000).round();

  /// 采集分片大小只在变化时写一次：每片解码的固定开销决定 RTF，
  /// 分片越小（20–40 ms）固定开销占比越高，实时余量越少。
  void _logChunkSize(int samples) {
    if (samples == _lastChunkSamples) return;
    _lastChunkSamples = samples;
    AppLog.instance.event('voice', 'audio_chunk', {
      'samples': samples,
      'ms': (samples * 1000 / 16000).round(),
    });
  }

  /// 解码积压观测：队列只增不减 = 解码吞吐跟不上实时（文本与滚动一起卡）。
  void _logAsrLag(AsrTick tick) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final processed = tick.processedAudioMs;
    final deltaAudio = processed - _lastTickAudioMs;
    final deltaDecode = tick.decodeTotalMs - _lastTickDecodeMs;
    final backlog = _engine.backlogMs;
    if (now - _lastLagLogMs < 2000) return;
    _lastLagLogMs = now;
    AppLog.instance.event('voice', 'asr_lag', {
      'backlogMs': backlog.round(),
      'fedMs': _engine.fedAudioMs.round(),
      'processedMs': processed.round(),
      'rtf': deltaAudio <= 0
          ? -1
          : (deltaDecode / deltaAudio * 1000).round() / 1000,
      'decodeMs': tick.decodeMs.round(),
    });
    _lastTickAudioMs = processed;
    _lastTickDecodeMs = tick.decodeTotalMs;
  }

  void _onAsrUpdate(AsrUpdate update) {
    if (_disposed) return;
    final text = update.text.trim();
    if (text.isEmpty) return;
    _health.onText(DateTime.now());

    // 窗口起点跟页面阅读位置，而不是跟踪器：
    // 跟踪器是「根据文本推出来的位置」，页面锚点才是用户真正看到的位置。
    // 两者一旦分叉（手动拖动/跳回开头/闸门夹行），以跟踪器为起点会让对齐
    // 窗口整体错位——cost≈span、置信度掉到 0.1、acceptFloor 拦死，页面永久
    // 不动。以页面为起点后，同一段文本总能对到用户当前所在的位置附近。
    final pageLine = anchorCharLine >= 0 ? anchorCharLine : tracker.line;
    // 偏移只在「偏移所属行 == 窗口起点行」时有效，跨行后旧偏移没有意义。
    final hint = anchorCharLine == pageLine ? anchorCharHint : 0;
    final align = _aligner.align(
      text,
      currentLine: pageLine,
      currentCharOffset: hint,
      isFinal: update.isFinal,
    );
    if (align == null) return;

    // 未命中/等待只刷新展示，不推进锚点、不污染弱命中与降级计数。
    final trackerUpdate = align.matched
        ? tracker.update(
            candidateLine: align.anchorLine,
            rawConfidence: align.confidence,
            isFinal: update.isFinal,
            spanLength: align.spanLength,
          )
        : tracker.snapshot();
    _logAlignMiss(align);

    // 识别原文仅用于 UI 展示，不写入日志（CODING §7）。
    onUpdate(
      VoiceFollowUpdate(
        tracker: trackerUpdate,
        align: align,
        partial: text,
        asr: update,
      ),
    );
  }

  int _lastAlignMissLogMs = 0;

  /// 对齐未命中 / 重锚被 +3 规则拦下：写一次带原因的日志（2 s 节流）。
  void _logAlignMiss(AlignResult align) {
    if (align.matched && align.suggestedLine < 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastAlignMissLogMs < 2000) return;
    _lastAlignMissLogMs = now;
    AppLog.instance.event('voice', 'align_miss', {
      'line': align.anchorLine,
      'pending': align.pending,
      'suggestedLine': align.suggestedLine,
      'isFinal': align.isFinal,
    });
  }

  /// 每秒评估一次健康度：状态变化才回调/写日志，避免日志刷屏。
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      final health = _health.evaluate(DateTime.now());
      if (health.kind != _lastHealthKind) {
        _lastHealthKind = health.kind;
        AppLog.instance.event('voice', 'health', health.toLog());
        onHealth?.call(health);
      }
      if (_micActive &&
          health.kind == VoiceHealthKind.captureStalled &&
          !_restartingCapture) {
        final now = DateTime.now();
        final last = _lastRestartAt;
        if (last == null ||
            now.difference(last) >= const Duration(seconds: 3)) {
          _lastRestartAt = now;
          unawaited(_restartCapture());
        }
      }
      // 分片还在进、心跳停了：引擎 isolate 卡死或已退出，重建引擎而不是静默冻结。
      if (_micActive &&
          health.kind == VoiceHealthKind.engineStalled &&
          !_restartingEngine) {
        final now = DateTime.now();
        final last = _lastEngineRestartAt;
        if (last == null ||
            now.difference(last) >= const Duration(seconds: 3)) {
          _lastEngineRestartAt = now;
          unawaited(_restartEngine('engine_stalled'));
        }
      }
    });
  }

  /// 自动重开采集（不动识别引擎与对齐索引），失败留待下一轮看门狗重试。
  Future<void> _restartCapture() async {
    if (_disposed || _restartingCapture) return;
    _restartingCapture = true;
    final attempt = ++_restartAttempts;
    try {
      await _audioSub?.cancel().timeout(const Duration(seconds: 3));
      _audioSub = null;
      await _audio.stop().timeout(const Duration(seconds: 3));
      await _listenCapture().timeout(const Duration(seconds: 8));
      _health.onCaptureRestarted(DateTime.now());
      _reportedCaptureError = false;
      AppLog.instance.event('voice', 'capture_restarted', {'attempt': attempt});
    } catch (error) {
      AppLog.instance.event('voice', 'capture_restart_failed', {
        'attempt': attempt,
        'error': '$error',
      });
    } finally {
      _restartingCapture = false;
    }
  }

  /// 重建识别引擎：isolate 退出/流报错/心跳停止时调用，带冷却与超时。
  ///
  /// 采集流与对齐索引保持不变；新引擎就绪后把心跳基准归零，避免刚重启
  /// 就被健康度判成「引擎卡死」而再次重建。
  Future<void> _restartEngine(String reason) async {
    if (_disposed || _restartingEngine) return;
    final model = _installedModel;
    if (model == null) return;
    final now = DateTime.now();
    final last = _lastEngineRestartAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastEngineRestartAt = now;
    _restartingEngine = true;
    final attempt = ++_engineRestartAttempts;
    AppLog.instance.event('voice', 'engine_restart', {
      'attempt': attempt,
      'reason': reason,
    });
    try {
      await _asrSub?.cancel().timeout(const Duration(seconds: 5));
      _asrSub = null;
      await _tickSub?.cancel().timeout(const Duration(seconds: 5));
      _tickSub = null;
      await _engine.dispose().timeout(const Duration(seconds: 5));
      _engine = SherpaAsrEngine();
      await _engine
          .start(model, tuning: _tuning)
          .timeout(const Duration(seconds: 45));
      _bindEngineStreams();
      _health.onTick(DateTime.now());
      _lastTickAudioMs = 0;
      _lastTickDecodeMs = 0;
      AppLog.instance.event('voice', 'engine_restarted', {'attempt': attempt});
    } catch (error) {
      AppLog.instance.event('voice', 'engine_restart_failed', {
        'attempt': attempt,
        'error': '$error',
      });
    } finally {
      _restartingEngine = false;
    }
  }

  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _audioSub?.cancel();
    _audioSub = null;
    await _audio.stop();
    await _asrSub?.cancel();
    _asrSub = null;
    await _tickSub?.cancel();
    _tickSub = null;
    await _engine.dispose();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}
