/// 语音识别的模糊匹配档位（C-09）。
///
/// 档位同时影响三处参数：
/// - 逐行推进闸门 `LineStepGate`：强命中阈值、弱命中阈值、final 加成、弱命中次数、单次最多前进行数；
/// - 对齐引擎 `AlignEngine`：滑窗前看行数（候选搜索范围）；
/// - 跟踪器 `AlignTracker`：低置信判定与回退抑制的底线。
///
/// 数值是产品可解释的固定档位，不做连续可调，避免用户面对无意义的小数。
enum MatchTolerance {
  /// 最谨慎：几乎只在听清整行后才推进；适合安静环境、照稿逐字念。
  veryStrict,

  /// 严格：宁可漏跟，不可抢行；适合安静环境、稿件与口播高度一致。
  strict,

  /// 标准：默认档位，等价于历史默认阈值。
  standard,

  /// 宽松：允许更远的候选与更低的置信；适合噪声环境、即兴发挥较多。
  loose,

  /// 最宽松：噪声大、自由发挥多时也尽量跟住；仍受 3 行跳读硬上限约束。
  veryLoose,
}

/// 档位对应的具体阈值。
class MatchProfile {
  /// 创建一份档位参数。
  const MatchProfile({
    required this.tolerance,
    required this.confirmConfidence,
    required this.weakConfidence,
    required this.finalBonus,
    required this.weakHitsRequired,
    required this.maxLeap,
    required this.lookAheadLines,
    required this.acceptFloor,
    required this.recoverConfidence,
  });

  /// 档位枚举。
  final MatchTolerance tolerance;

  /// 强命中阈值：原始（含 final 加成）置信度达到即立即推进。
  final double confirmConfidence;

  /// 弱命中下限：低于该值视为低置信，不推进。
  final double weakConfidence;

  /// final 结果的置信度加成。
  final double finalBonus;

  /// 弱命中需要连续命中的次数。
  final int weakHitsRequired;

  /// 单次允许前进的最大行数。
  final int maxLeap;

  /// 滑窗前看行数（对齐候选搜索范围）。
  final int lookAheadLines;

  /// 普通前向候选的接受底线（`AlignTracker.acceptFloor`）。
  final double acceptFloor;

  /// 退出降级态所需置信度（`AlignTracker.recoverConfidence`）。
  final double recoverConfidence;

  /// 最谨慎档参数：单次最多前进 1 行，弱命中需连续 3 次。
  static const MatchProfile veryStrictProfile = MatchProfile(
    tolerance: MatchTolerance.veryStrict,
    confirmConfidence: 0.78,
    weakConfidence: 0.52,
    finalBonus: 0.08,
    weakHitsRequired: 3,
    maxLeap: 1,
    lookAheadLines: 1,
    acceptFloor: 0.38,
    recoverConfidence: 0.68,
  );

  /// 严格档参数。
  static const MatchProfile strictProfile = MatchProfile(
    tolerance: MatchTolerance.strict,
    confirmConfidence: 0.70,
    weakConfidence: 0.45,
    finalBonus: 0.10,
    weakHitsRequired: 2,
    maxLeap: 2,
    lookAheadLines: 2,
    acceptFloor: 0.30,
    recoverConfidence: 0.60,
  );

  /// 标准档参数（历史默认值）。
  static const MatchProfile standardProfile = MatchProfile(
    tolerance: MatchTolerance.standard,
    confirmConfidence: 0.55,
    weakConfidence: 0.35,
    finalBonus: 0.15,
    weakHitsRequired: 2,
    maxLeap: 3,
    lookAheadLines: 3,
    acceptFloor: 0.20,
    recoverConfidence: 0.50,
  );

  /// 宽松档参数。
  ///
  /// [maxLeap] 固定在 3 行：宽松只放宽置信门槛与前看行数，
  /// 不放开单次跳读距离（见 `limits.dart` 的硬上限）。
  static const MatchProfile looseProfile = MatchProfile(
    tolerance: MatchTolerance.loose,
    confirmConfidence: 0.42,
    weakConfidence: 0.22,
    finalBonus: 0.20,
    weakHitsRequired: 1,
    maxLeap: 3,
    lookAheadLines: 4,
    acceptFloor: 0.12,
    recoverConfidence: 0.40,
  );

  /// 最宽松档参数（跳读距离仍固定不超过 3 行）。
  static const MatchProfile veryLooseProfile = MatchProfile(
    tolerance: MatchTolerance.veryLoose,
    confirmConfidence: 0.32,
    weakConfidence: 0.15,
    finalBonus: 0.25,
    weakHitsRequired: 1,
    maxLeap: 3,
    lookAheadLines: 5,
    acceptFloor: 0.06,
    recoverConfidence: 0.30,
  );

  /// 按档位取参数。
  static MatchProfile of(MatchTolerance tolerance) {
    switch (tolerance) {
      case MatchTolerance.veryStrict:
        return veryStrictProfile;
      case MatchTolerance.strict:
        return strictProfile;
      case MatchTolerance.standard:
        return standardProfile;
      case MatchTolerance.loose:
        return looseProfile;
      case MatchTolerance.veryLoose:
        return veryLooseProfile;
    }
  }

  /// 从持久化字符串解析，未知值回落到 [MatchTolerance.standard]。
  static MatchTolerance parse(Object? value) {
    if (value is String) {
      for (final item in MatchTolerance.values) {
        if (item.name == value) return item;
      }
    }
    return MatchTolerance.standard;
  }
}
