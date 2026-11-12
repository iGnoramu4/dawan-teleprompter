/// 连续朗读检测：识别是否处于「持续有输出、锚点在推进」的连续语音流。
///
/// 只有在这种状态下才允许把闸门从手动档位放宽一档；静音、噪声或识别
/// 长时间不推进时必须立刻退回严格档位，避免放宽后误触发。
///
/// 进入条件（全部满足，持续 [enterStreak] 次更新）：
/// 1. 相邻两次更新间隔 ≤ [exitSilence]（否则视为断流，重新计数）；
/// 2. 每次置信度 ≥ [minConfidence]；
/// 3. 最近 [advanceWindow] 内锚点至少推进 [minAdvances] 行。
///
/// 退出条件（任一满足）：
/// 1. 超过 [exitSilence] 没有新的识别输出（静音 / 断流）；
/// 2. 连续 [exitLowStreak] 次置信度低于 [minConfidence]（低置信堆积）。
class ContinuousSpeechMonitor {
  /// 创建检测器。
  ContinuousSpeechMonitor({
    this.enabled = true,
    this.enterStreak = 5,
    this.exitSilence = const Duration(milliseconds: 2500),
    this.exitLowStreak = 3,
    this.minConfidence = 0.35,
    this.minAdvances = 3,
    this.advanceWindow = const Duration(seconds: 8),
  });

  /// 是否启用自适应（关闭时 [relaxed] 恒为 false，用于对照实验）。
  final bool enabled;

  /// 进入放宽态所需的连续合格更新次数。
  final int enterStreak;

  /// 多久没有输出就退出放宽态。
  final Duration exitSilence;

  /// 连续低置信多少次退出放宽态。
  final int exitLowStreak;

  /// 视为「有把握」的置信度下限。
  final double minConfidence;

  /// 进入放宽态所需的锚点推进行数。
  final int minAdvances;

  /// 统计推进行数的时间窗口。
  final Duration advanceWindow;

  DateTime? _lastAt;
  int _goodStreak = 0;
  int _lowStreak = 0;
  int _lastLine = 0;
  final List<(DateTime, int)> _advances = <(DateTime, int)>[];
  bool _relaxed = false;

  /// 当前是否处于放宽态。
  bool get relaxed => enabled && _relaxed;

  /// 消费一条识别更新。
  ///
  /// [line] 为更新后的锚点行；[confidence] 为原始对齐置信度。
  void onUpdate({
    required DateTime at,
    required double confidence,
    required int line,
  }) {
    if (!enabled) return;
    final last = _lastAt;
    if (last != null && at.difference(last) > exitSilence) {
      _exit();
    }
    _lastAt = at;

    if (line > _lastLine) {
      _advances.add((at, line - _lastLine));
      _lastLine = line;
    }
    // 只保留窗口内的推进记录。
    _advances.removeWhere((item) => at.difference(item.$1) > advanceWindow);

    if (confidence >= minConfidence) {
      _lowStreak = 0;
      _goodStreak++;
    } else {
      _lowStreak++;
      _goodStreak = 0;
      if (_lowStreak >= exitLowStreak) _exit();
    }

    if (!_relaxed &&
        _goodStreak >= enterStreak &&
        _advanceCount() >= minAdvances) {
      _relaxed = true;
    }
  }

  /// 周期检查（静音/断流时退出放宽态）。
  void tick(DateTime at) {
    if (!enabled || !_relaxed) return;
    final last = _lastAt;
    if (last == null || at.difference(last) > exitSilence) _exit();
  }

  int _advanceCount() => _advances.fold(0, (sum, item) => sum + item.$2);

  void _exit() {
    _relaxed = false;
    _goodStreak = 0;
    _lowStreak = 0;
    _advances.clear();
  }
}
