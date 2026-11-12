import 'dart:math' as math;

import 'limits.dart';
import 'match_tolerance.dart';
import 'normalizer.dart';
import 'script_index.dart';

/// early arm 的一次判定结果。
class EarlyArmDecision {
  /// 创建判定结果。
  const EarlyArmDecision({required this.line, required this.armed});

  /// 建议提前切到的语义行；未触发时等于当前行。
  final int line;

  /// 是否满足提前跨行条件。
  final bool armed;
}

/// 下一行前缀提前跨行（early arm）。
///
/// 当当前行已读比例达到 [fraction]，且识别文本尾部与下一语义行的前
/// [tokens] 个 token 逐个模糊匹配时，允许把目标提前设为下一行。
/// 连续 2 次命中或 final 结果才真正触发，避免 partial 抖动导致抢行。
///
/// 严格档关闭；标准档要求前缀全部命中；宽松档因 [margin] 更大，
/// 在更长的前缀下允许极少量错配。
class EarlyArmDetector {
  /// 创建检测器。
  EarlyArmDetector({
    required this.index,
    this.fraction = 0.55,
    this.tokens = 2,
    this.margin = 0.10,
    this.enabled = true,
  });

  /// 按匹配档位创建：两档最严关闭，越宽松 [margin] 越大。
  factory EarlyArmDetector.fromProfile(
    ScriptIndex index,
    MatchProfile profile,
  ) {
    final tolerance = profile.tolerance;
    final wide = tolerance == MatchTolerance.loose ||
        tolerance == MatchTolerance.veryLoose;
    return EarlyArmDetector(
      index: index,
      margin: wide ? 0.15 : 0.10,
      enabled: tolerance != MatchTolerance.veryStrict &&
          tolerance != MatchTolerance.strict,
    );
  }

  /// 台本索引（重排后可整体替换）。
  ScriptIndex index;

  /// 当前行已读比例下限（0–1）。
  final double fraction;

  /// 下一行前缀参与比较的 token 数。
  final int tokens;

  /// 阈值放宽量（越小越严格）。
  final double margin;

  /// 是否启用提前跨行。
  final bool enabled;

  /// 短尾捷径：短段的最大 token 数。
  final int shortTailTokens = 3;

  /// 短尾捷径：识别尾部最多用多少个 token 覆盖两段。
  final int shortTailWindow = 4;

  int _pendingLine = -1;
  int _pendingHits = 0;

  /// 清空连续命中计数（手动跳转 / 重新开始跟随）。
  void reset() {
    _pendingLine = -1;
    _pendingHits = 0;
  }

  /// 重排后替换索引并清空待确认状态。
  void replaceIndex(ScriptIndex next) {
    index = next;
    reset();
  }

  /// 判定是否应提前切到下一行。
  ///
  /// [anchorToken] 为本次对齐命中的台本 token；[spoken] 为归一化后的识别
  /// token 流；[isFinal] 为真时一次命中即可触发。
  EarlyArmDecision evaluate({
    required int currentLine,
    required int anchorToken,
    required List<NormToken> spoken,
    required bool isFinal,
  }) {
    if (!enabled) {
      return EarlyArmDecision(line: currentLine, armed: false);
    }
    final next = currentLine + 1;
    if (next >= index.lineCount || index.tokenCount == 0) {
      reset();
      return EarlyArmDecision(line: currentLine, armed: false);
    }

    final start = index.startTokenOfLine(currentLine);
    final end = index.endTokenOfLine(currentLine);
    final lineTokens = end - start;
    if (lineTokens <= 0) {
      reset();
      return EarlyArmDecision(line: currentLine, armed: false);
    }
    final spokenFraction =
        ((anchorToken - start + 1) / lineTokens).clamp(0.0, 1.0);
    if (spokenFraction < fraction) {
      reset();
      return EarlyArmDecision(line: currentLine, armed: false);
    }

    final following = index.endTokenOfLine(next) - end;
    final count = math.min(tokens, following);
    if (count <= 0 || spoken.length < count) {
      reset();
      return EarlyArmDecision(line: currentLine, armed: false);
    }

    // 短尾捷径：下一段很短（≤3 token）且再下一段也被识别尾部完整覆盖时，
    // 一次瞄准两段之后，避免在短段上逐段等待。
    // 不采用「把匹配缓冲裁到 2 行」的做法：那会裁掉行首，导致永远匹配不上。
    final nextEnd = end + following;
    var target = next;
    var shortLeap = false;
    if (following <= shortTailTokens && spokenFraction >= 0.95) {
      final after = next + 1;
      if (after < index.lineCount) {
        final afterCount = index.endTokenOfLine(after) - nextEnd;
        if (afterCount > 0 &&
            afterCount <= shortTailTokens &&
            following + afterCount <= shortTailWindow &&
            spoken.length >= following + afterCount) {
          var covered = true;
          for (var i = 0; i < afterCount; i++) {
            if (!spoken[spoken.length - afterCount + i]
                .matches(index.tokens[nextEnd + i])) {
              covered = false;
              break;
            }
          }
          for (var i = 0; i < following && covered; i++) {
            if (!spoken[spoken.length - afterCount - following + i]
                .matches(index.tokens[end + i])) {
              covered = false;
            }
          }
          if (covered) {
            target = after;
            shortLeap = true;
          }
        }
      }
    }

    if (!shortLeap) {
      var hits = 0;
      for (var i = 0; i < count; i++) {
        if (spoken[spoken.length - count + i].matches(index.tokens[end + i])) {
          hits++;
        }
      }
      final required = 1.0 - margin / 2;
      if (hits / count < required) {
        reset();
        return EarlyArmDecision(line: currentLine, armed: false);
      }
    }

    // 硬上限：短尾捷径最多跨两段，但任何路径都不得超过 3 行。
    if (target > currentLine + maxAutoLeapLines) {
      target = currentLine + maxAutoLeapLines;
    }

    if (_pendingLine == target) {
      _pendingHits++;
    } else {
      _pendingLine = target;
      _pendingHits = 1;
    }
    if (!isFinal && _pendingHits < 2) {
      return EarlyArmDecision(line: currentLine, armed: false);
    }
    reset();
    return EarlyArmDecision(line: target, armed: true);
  }
}
