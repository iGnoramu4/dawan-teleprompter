/// 自动推进的硬上限（行）。
///
/// 任何档位、任何路径——逐行闸门、锚点跟踪器、提前跨行（early arm）、
/// 候选跳转——单次自动推进都不得超过该行数。跳读对提词器是致命错误
/// （用户会直接失去位置），因此把它写成全局不变量而不是可配置项，
/// 由 `core_alignment` 的测试守住，避免后续调参时被改回去。
const int maxAutoLeapLines = 3;

/// 允许跨行（>1 行）所需的最小证据跨度（音节数）。
///
/// 快速朗读时识别错误率上升，2–3 个音节偶然同音就能给出 0.6–0.7 的置信度；
/// 若据此一次跨 3 行，页面会抢到朗读位置前面，随后整段语音落在锚点之前
/// （锚点单调不回退），表现为「读快了就丢」。短跨度只允许逐行推进。
const int minLeapSpanSyllables = 6;

/// 允许跨行（>1 行）所需的最低置信度。
///
/// 与 [minLeapSpanSyllables] 同时生效：任一条不满足都只允许 +1 行。
const double minLeapConfidence = 0.8;

/// 依据本次证据强度给出单次允许的跨行上限（行）。
///
/// 只回答「一次能跳几行」，是否真的推进仍由闸门/跟踪器各自的门槛决定。
int leapCapForEvidence({
  required int spanLength,
  required double confidence,
}) {
  if (spanLength < minLeapSpanSyllables) return 1;
  if (confidence < minLeapConfidence) return 1;
  return maxAutoLeapLines;
}
