/// 语音跟随时「卡住」的三种不同原因。
///
/// 三者必须分开诊断，不能都复用「未检测到语音」：
/// - [captureStalled]：麦克风分片停止（前台服务被杀、权限被收回、音频焦点丢失）；
/// - [engineStalled]：分片还在进，但识别引擎没有解码心跳（引擎卡死/isolate 异常）；
/// - [silent]：引擎在正常解码，但确实没有识别出文字（用户没说话或说话太轻）。
/// 闸门不推进属于第四类，由阅读页结合锚点推进时间判断。
enum VoiceHealthKind {
  /// 尚未开始收音。
  idle,

  /// 采集与解码都正常。
  capturing,

  /// 引擎在解码，但一段时间没有出字。
  silent,

  /// 音频分片断流。
  captureStalled,

  /// 有音频分片但没有解码心跳。
  engineStalled,
}

/// 一次语音健康度快照。
class VoiceHealth {
  const VoiceHealth({
    required this.kind,
    required this.sinceChunkMs,
    required this.sinceTickMs,
    required this.sinceTextMs,
    required this.chunkCount,
    required this.tickCount,
    required this.textCount,
    required this.captureRestarts,
  });

  /// 当前判定。
  final VoiceHealthKind kind;

  /// 距最近一次音频分片的毫秒数。
  final int sinceChunkMs;

  /// 距最近一次解码心跳的毫秒数。
  final int sinceTickMs;

  /// 距最近一次识别文本更新的毫秒数。
  final int sinceTextMs;

  /// 累计音频分片数。
  final int chunkCount;

  /// 累计解码心跳数。
  final int tickCount;

  /// 累计文本更新数。
  final int textCount;

  /// 自动重开采集次数。
  final int captureRestarts;

  /// 日志字段（不含识别文字，符合 CODING §7）。
  Map<String, Object?> toLog() => {
        'kind': kind.name,
        'sinceChunkMs': sinceChunkMs,
        'sinceTickMs': sinceTickMs,
        'sinceTextMs': sinceTextMs,
        'chunks': chunkCount,
        'ticks': tickCount,
        'texts': textCount,
        'restarts': captureRestarts,
      };
}

/// 语音健康判定的纯逻辑（无插件依赖，可单测）。
class VoiceHealthMonitor {
  VoiceHealthMonitor({
    this.captureStallAfter = const Duration(milliseconds: 2500),
    this.engineStallAfter = const Duration(seconds: 3),
    this.silenceAfter = const Duration(seconds: 4),
  });

  /// 多久没有音频分片就判定采集停止。
  final Duration captureStallAfter;

  /// 多久没有解码心跳就判定引擎卡死。
  final Duration engineStallAfter;

  /// 有心跳但多久没有出字就判定静音。
  final Duration silenceAfter;

  DateTime? _startedAt;
  DateTime? _lastChunkAt;
  DateTime? _lastTickAt;
  DateTime? _lastTextAt;
  bool _captureClosed = false;
  int _chunks = 0;
  int _ticks = 0;
  int _texts = 0;
  int _restarts = 0;

  /// 是否已进入收音会话。
  bool get active => _startedAt != null;

  /// 开始一轮收音（采集开始时间，避免开局立刻误判）。
  void start(DateTime now) {
    _startedAt = now;
    _lastChunkAt = now;
    _lastTickAt = now;
    _lastTextAt = now;
    _captureClosed = false;
    _chunks = 0;
    _ticks = 0;
    _texts = 0;
    _restarts = 0;
  }

  /// 收到一段音频分片。
  void onChunk(DateTime now) {
    _lastChunkAt = now;
    _captureClosed = false;
    _chunks++;
  }

  /// 收到一次解码心跳。
  void onTick(DateTime now) {
    _lastTickAt = now;
    _ticks++;
  }

  /// 收到一次识别文本更新。
  void onText(DateTime now) {
    _lastTextAt = now;
    _texts++;
  }

  /// 采集流关闭（插件上报 onDone / onError）。
  void onCaptureClosed() {
    _captureClosed = true;
  }

  /// 记录一次自动重开采集。
  void onCaptureRestarted(DateTime now) {
    _lastChunkAt = now;
    _lastTickAt = now;
    _restarts++;
  }

  /// 当前判定。
  VoiceHealth evaluate(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return const VoiceHealth(
        kind: VoiceHealthKind.idle,
        sinceChunkMs: 0,
        sinceTickMs: 0,
        sinceTextMs: 0,
        chunkCount: 0,
        tickCount: 0,
        textCount: 0,
        captureRestarts: 0,
      );
    }
    final sinceChunk = now.difference(_lastChunkAt ?? startedAt);
    final sinceTick = now.difference(_lastTickAt ?? startedAt);
    final sinceText = now.difference(_lastTextAt ?? startedAt);

    final VoiceHealthKind kind;
    if (_captureClosed || sinceChunk > captureStallAfter) {
      kind = VoiceHealthKind.captureStalled;
    } else if (sinceTick > engineStallAfter) {
      kind = VoiceHealthKind.engineStalled;
    } else if (sinceText > silenceAfter) {
      kind = VoiceHealthKind.silent;
    } else {
      kind = VoiceHealthKind.capturing;
    }
    return VoiceHealth(
      kind: kind,
      sinceChunkMs: sinceChunk.inMilliseconds,
      sinceTickMs: sinceTick.inMilliseconds,
      sinceTextMs: sinceText.inMilliseconds,
      chunkCount: _chunks,
      tickCount: _ticks,
      textCount: _texts,
      captureRestarts: _restarts,
    );
  }
}
