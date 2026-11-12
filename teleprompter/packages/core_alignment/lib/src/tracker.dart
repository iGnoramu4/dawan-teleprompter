import 'limits.dart';
import 'match_tolerance.dart';

/// 回跳抑制 / 跳读判定 / 低置信降级（§5.5 步骤 3）。
class TrackerUpdate {
  /// 创建一次跟踪结果。
  const TrackerUpdate({
    required this.line,
    required this.confidence,
    required this.accepted,
    required this.fastCatchUp,
    required this.degraded,
    required this.heldBack,
  });

  /// 当前锚点行。
  final int line;

  /// 平滑后的置信度。
  final double confidence;

  /// 本次是否接受了新的锚点行。
  final bool accepted;

  /// 是否判定为"跳读"，滚动控制器应使用快速追赶曲线。
  final bool fastCatchUp;

  /// 连续低置信，已进入降级态。
  final bool degraded;

  /// 候选被回跳抑制（噪声/口误）。
  final bool heldBack;

  @override
  String toString() =>
      'TrackerUpdate(line=$line, conf=${confidence.toStringAsFixed(2)}, '
      'accepted=$accepted, fast=$fastCatchUp, degraded=$degraded)';
}

/// 锚点跟踪器：把对齐候选行转换为稳定的阅读位置。
class AlignTracker {
  /// 创建跟踪器。
  ///
  /// [weakConfidence] 为低置信底线（默认 0.35）；[acceptFloor] 是普通前向候选的
  /// 接受底线（默认 0.2）；[recoverConfidence] 是退出降级态所需置信度（默认 0.5）。
  AlignTracker({
    required this.lineCount,
    int initialLine = 0,
    this.weakConfidence = 0.35,
    this.acceptFloor = 0.2,
    this.recoverConfidence = 0.5,
    this.leapConfidence = 0.6,
  }) : _line = initialLine.clamp(0, lineCount == 0 ? 0 : lineCount - 1);

  /// 按匹配档位创建跟踪器（与 `LineStepGate.fromProfile` 同源）。
  factory AlignTracker.fromProfile(
    MatchProfile profile, {
    required int lineCount,
    int initialLine = 0,
  }) {
    return AlignTracker(
      lineCount: lineCount,
      initialLine: initialLine,
      weakConfidence: profile.weakConfidence,
      acceptFloor: profile.acceptFloor,
      recoverConfidence: profile.recoverConfidence,
    );
  }

  /// 低置信底线。
  double weakConfidence;

  /// 普通前向候选的接受底线。
  double acceptFloor;

  /// 退出降级态的置信度。
  double recoverConfidence;

  /// 单次跨行（>1 行）所需的原始置信度。
  ///
  /// 与 [LineStepGate.leapConfidence] 同口径：低置信候选即使被接受，
  /// 每次也最多前进一行，避免「宽松档 + 端点 final 加成」在多条 partial
  /// 之间累积成连续 2–3 行的棘轮式跳读。
  double leapConfidence;

  /// 运行中切换匹配档位（保留当前锚点与平滑状态）。
  void applyProfile(MatchProfile profile) {
    weakConfidence = profile.weakConfidence;
    acceptFloor = profile.acceptFloor;
    recoverConfidence = profile.recoverConfidence;
  }

  /// 总行数。
  final int lineCount;

  int _line;
  double _confidence = 0;
  int _lowConfStreak = 0;
  bool _degraded = false;
  int _leapCandidate = -1;
  int _leapHits = 0;

  /// 当前锚点行。
  int get line => _line;

  /// 当前置信度。
  double get confidence => _confidence;

  /// 是否处于低置信降级态。
  bool get degraded => _degraded;

  /// 手动跳转（句级跳转/时间轴拖动）直接落位。
  void forceLine(int line) {
    _line = _clamp(line);
    _lowConfStreak = 0;
    _leapCandidate = -1;
    _leapHits = 0;
  }

  /// 只读快照：未命中/等待时用于刷新 UI，不推进锚点、不改平滑与降级状态。
  ///
  /// 对齐失败不等于识别失败：状态框仍应显示这次识别文本与解码耗时，
  /// 只是阅读位置保持不动。
  TrackerUpdate snapshot() => TrackerUpdate(
        line: _line,
        confidence: _confidence,
        accepted: false,
        fastCatchUp: false,
        degraded: _degraded,
        heldBack: false,
      );

  /// 清空平滑状态与待确认回退，并把锚点行归零。
  ///
  /// 锚点行必须一起清掉：调用方（手动跳行、重新开始跟随、换稿）随后会用
  /// [forceLine] 指定真实行；只清平滑状态而留下旧行号，会让对齐窗口停留在
  /// 上一轮的位置，形成「窗口错位 → 全是插入惩罚 → 置信度 0.1 → 永久不动」。
  void reset() {
    _line = 0;
    _confidence = 0;
    _lowConfStreak = 0;
    _degraded = false;
    _leapCandidate = -1;
    _leapHits = 0;
  }

  /// 根据候选行与原始置信度更新锚点。
  ///
  /// [spanLength] 是本次命中的证据跨度（音节数）。短跨度或次高置信的远候选
  /// 只允许前进一行，避免「2–3 个音节偶然同音 → 一次跨 3 行 → 抢到朗读前面」。
  TrackerUpdate update({
    required int candidateLine,
    required double rawConfidence,
    bool isFinal = false,
    int spanLength = 0,
  }) {
    final raw = _clamp(candidateLine);
    // 硬上限：候选跳转（对齐器远看、界面长候选）也不得单次越过 3 行。
    final cap = _clamp(_line + maxAutoLeapLines);
    final capped = raw > cap;
    var candidate = capped ? cap : raw;
    // 短跨度 / 次高置信：一次最多 +1。同一远候选连续两次也只是稳定性证据，
    // 不构成跨度证据，因此不再放行跨行。
    final leapCap =
        leapCapForEvidence(spanLength: spanLength, confidence: rawConfidence);
    if (raw > _line + leapCap) candidate = _line + leapCap;
    // 低置信远候选：单步 3 行上限挡不住「每次 2–3 行」的连续累积。
    // 先只前进一行；只有同一个远候选连续出现两次（真实位置稳定）才允许跨行，
    // 这样真机上 5→7→10 这种漂移候选不会连锁，而快速朗读的稳定候选仍能追上。
    if (raw > _line + 1 && rawConfidence < leapConfidence) {
      if (_leapCandidate == raw) {
        _leapHits++;
      } else {
        _leapCandidate = raw;
        _leapHits = 1;
      }
      if (_leapHits < 2) candidate = _line + 1;
    } else {
      _leapCandidate = -1;
      _leapHits = 0;
    }
    var accepted = false;
    var fastCatchUp = false;
    var heldBack = false;

    if (candidate < _line) {
      // 锚点默认单调不后退：口误、重读、噪声都不能把阅读位置往回拖。
      // 回退只来自用户显式操作（forceLine / 手动跳行）。
      heldBack = true;
    } else {
      final farAhead = candidate - _line > 1;
      // 远处候选同样要过置信底线；final 不再无条件放行。
      if (rawConfidence >= acceptFloor) {
        accepted = true;
        fastCatchUp = farAhead;
      } else {
        heldBack = true;
      }
    }

    if (accepted) _line = candidate;

    if (rawConfidence > 0) {
      _confidence = _confidence == 0
          ? rawConfidence
          : 0.7 * _confidence + 0.3 * rawConfidence;
    }

    if (rawConfidence < weakConfidence) {
      _lowConfStreak++;
    } else {
      _lowConfStreak = 0;
    }
    if (_lowConfStreak >= 3) _degraded = true;
    if (rawConfidence >= recoverConfidence) _degraded = false;

    return TrackerUpdate(
      line: _line,
      confidence: _confidence,
      accepted: accepted,
      fastCatchUp: fastCatchUp,
      degraded: _degraded,
      heldBack: heldBack,
    );
  }

  int _clamp(int line) {
    if (lineCount == 0) return 0;
    if (line < 0) return 0;
    if (line >= lineCount) return lineCount - 1;
    return line;
  }
}
