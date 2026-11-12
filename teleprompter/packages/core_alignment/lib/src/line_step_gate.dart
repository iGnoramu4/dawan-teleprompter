import 'dart:math' as math;

import 'limits.dart';
import 'match_tolerance.dart';

/// 逐行跟随的判定结果。
class LineStepDecision {
  /// 创建一次判定结果。
  const LineStepDecision({
    required this.line,
    required this.advanced,
    required this.leap,
    required this.waiting,
    required this.lowConfidence,
    required this.degraded,
  });

  /// 判定后的锚点行（未推进时等于当前行）。
  final int line;

  /// 本次是否推进了锚点行。
  final bool advanced;

  /// 是否属于越级推进（跳读），滚动层可启用快速追赶。
  final bool leap;

  /// 候选行已出现但置信度不足，正在等待下一次连续命中。
  final bool waiting;

  /// 本次识别为低置信。
  final bool lowConfidence;

  /// 连续低置信达到阈值，进入降级态（页面应提示）。
  final bool degraded;

  @override
  String toString() => 'LineStepDecision(line: $line, advanced: $advanced, '
      'leap: $leap, waiting: $waiting, low: $lowConfidence)';
}

/// 逐行推进闸门（§4.3 C-09 逐行跟随模式）。
///
/// 与 `AlignTracker` 的差别：跟踪器只负责"候选行是否可信"，本闸门负责
/// "什么时候允许把阅读锚点切换到下一行"。默认参数：
/// - 强命中：原始置信度 ≥ 0.55（final 结果额外 +0.15）立即推进 1 行；
/// - 弱命中：0.35–0.55 需连续 2 次命中同一行（或更远的行）才推进；
/// - 低于 0.35 不推进，连续 3 次进入降级态；
/// - 单次最多前进 [maxLeap] 行（任何档位都不超过 [maxAutoLeapLines]），
///   超过时先推进到上限，由后续更新继续收敛；
/// - 不因识别回退而回跳（口误不回跳），回退只允许手动操作。
class LineStepGate {
  /// 创建闸门。
  LineStepGate({
    this.confirmConfidence = 0.55,
    this.weakConfidence = 0.35,
    this.weakHitsRequired = 2,
    int maxLeap = maxAutoLeapLines,
    this.finalBonus = 0.15,
    this.degradeAfter = 3,
  }) : maxLeap = maxLeap < 1
            ? 1
            : (maxLeap > maxAutoLeapLines ? maxAutoLeapLines : maxLeap);

  /// 按匹配档位创建闸门（设置页档位 → 阈值）。
  factory LineStepGate.fromProfile(MatchProfile profile) {
    return LineStepGate(
      confirmConfidence: profile.confirmConfidence,
      weakConfidence: profile.weakConfidence,
      weakHitsRequired: profile.weakHitsRequired,
      maxLeap: profile.maxLeap,
      finalBonus: profile.finalBonus,
    );
  }

  /// 强命中阈值。
  final double confirmConfidence;

  /// 弱命中阈值。
  final double weakConfidence;

  /// 弱命中需要的连续次数。
  final int weakHitsRequired;

  /// 单次允许前进的最大行数。
  final int maxLeap;

  /// final 结果的置信度加成。
  final double finalBonus;

  /// 连续低置信达到该次数后进入降级态。
  final int degradeAfter;

  /// 自适应放宽量：连续朗读时强命中阈值下调的值（不改变手动档位本身）。
  static const double relaxedDrop = 0.08;

  bool _relaxed = false;

  /// 是否处于连续朗读放宽态。
  bool get relaxed => _relaxed;

  /// 切换放宽态（由 [ContinuousSpeechMonitor] 驱动）。
  ///
  /// 切换时清空待确认状态：用旧阈值累积的弱命中次数不能带到新阈值下。
  set relaxed(bool value) {
    if (value == _relaxed) return;
    _relaxed = value;
    _pendingLine = -1;
    _weakHits = 0;
  }

  /// 当前生效的强命中阈值。
  double get effectiveConfirm => _relaxed
      ? (confirmConfidence - relaxedDrop).clamp(0.0, 1.0)
      : confirmConfidence;

  /// 当前生效的弱命中阈值。
  double get effectiveWeak => _relaxed
      ? (weakConfidence - relaxedDrop).clamp(0.0, 1.0)
      : weakConfidence;

  /// 当前生效的弱命中次数（放宽态减 1，最少 1 次）。
  int get effectiveWeakHits => _relaxed && weakHitsRequired > 1
      ? weakHitsRequired - 1
      : weakHitsRequired;

  int _pendingLine = -1;
  int _weakHits = 0;
  int _lowStreak = 0;

  /// 清空待确认状态（手动跳转 / 重新开始跟随）。
  void reset() {
    _pendingLine = -1;
    _weakHits = 0;
    _lowStreak = 0;
  }

  /// 根据候选行与原始置信度判定是否切行。
  LineStepDecision evaluate({
    required int currentLine,
    required int candidateLine,
    required double confidence,
    bool isFinal = false,
    int spanLength = 0,
  }) {
    final effective = (confidence + (isFinal ? finalBonus : 0)).clamp(0.0, 1.0);
    final low = effective < effectiveWeak;
    if (low) {
      _lowStreak++;
    } else {
      _lowStreak = 0;
    }
    final degraded = _lowStreak >= degradeAfter;

    // 不前进（含回退候选）：行内保持稳定，等待下一次识别。
    if (candidateLine <= currentLine) {
      _pendingLine = -1;
      _weakHits = 0;
      return LineStepDecision(
        line: currentLine,
        advanced: false,
        leap: false,
        waiting: false,
        lowConfidence: low,
        degraded: degraded,
      );
    }

    final delta = candidateLine - currentLine;

    // 越级限制：远处候选先夹到上限，但仍要过置信门槛；
    // 低置信的远处候选不能因为「距离足够远」就白送 maxLeap 行（P3 跳读）。
    // 短跨度（<6 音节）或次高置信（<0.8）只允许逐行推进：这是「读快了抢跑」
    // 的主要来源，2–3 个音节的偶然同音不应把整页推过去。
    final allowed = math.min(
      maxLeap,
      leapCapForEvidence(spanLength: spanLength, confidence: effective),
    );
    var target = candidateLine;
    if (delta > allowed) target = currentLine + allowed;

    if (effective >= effectiveConfirm) {
      _pendingLine = -1;
      _weakHits = 0;
      return LineStepDecision(
        line: target,
        advanced: true,
        leap: target - currentLine > 1,
        waiting: false,
        lowConfidence: false,
        degraded: degraded,
      );
    }

    // 弱命中：需要连续命中同一行或更远的候选。
    if (!low) {
      if (_pendingLine >= currentLine + 1 && target >= _pendingLine) {
        _weakHits++;
      } else {
        _pendingLine = target;
        _weakHits = 1;
      }
      if (_weakHits >= effectiveWeakHits) {
        final confirmed = _pendingLine;
        _pendingLine = -1;
        _weakHits = 0;
        return LineStepDecision(
          line: confirmed,
          advanced: true,
          leap: confirmed - currentLine > 1,
          waiting: false,
          lowConfidence: false,
          degraded: degraded,
        );
      }
      return LineStepDecision(
        line: currentLine,
        advanced: false,
        leap: false,
        waiting: true,
        lowConfidence: false,
        degraded: degraded,
      );
    }

    _pendingLine = -1;
    _weakHits = 0;
    return LineStepDecision(
      line: currentLine,
      advanced: false,
      leap: false,
      waiting: false,
      lowConfidence: true,
      degraded: degraded,
    );
  }
}
