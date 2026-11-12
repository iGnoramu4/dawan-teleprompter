/// 按可用宽度与字号推算每行可容纳的字数（§4.4 L-04 自动断行）。
///
/// 纯计算，不依赖 Flutter；渲染端只需把舞台宽度与字号传进来即可。
/// 结果用于 `ScriptModel` 的断行，字号、边距、屏幕旋转或窗口尺寸变化后重算。
class LineFit {
  const LineFit._();

  /// 自动断行的字数下限（极窄窗口仍保留可读性）。
  static const int minChars = 6;

  /// 自动断行的字数上限（超大屏避免一行过长）。
  static const int maxChars = 80;

  /// 行内左右留白总和（px），与阅读页 `TextPainter` 的 `maxWidth - 14` 对齐。
  static const double rowPadding = 14;

  /// 保守系数：字形实际宽度可能略大于标称 em，宁可少放一个字也不溢出折行。
  static const double safety = 1.02;

  /// 全角字符（CJK、全角标点）的宽度，单位为 em。
  static const double wideEm = 1;

  /// 半角字符（拉丁字母、数字、半角标点）的估算宽度，单位为 em。
  static const double narrowEm = 0.52;

  /// 按文本中全角/半角占比估算平均字宽（em）。
  ///
  /// 空文本按全角处理（中文台本为默认场景）。
  static double averageEm(String text) {
    var wide = 0;
    var narrow = 0;
    for (final rune in text.runes) {
      if (rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0x0D) {
        continue;
      }
      if (_isWide(rune)) {
        wide++;
      } else {
        narrow++;
      }
    }
    final total = wide + narrow;
    if (total == 0) return wideEm;
    return (wide * wideEm + narrow * narrowEm) / total;
  }

  /// 估算 [width] 宽度内每行能放下的字数。
  ///
  /// [fontSize] 字号（px）；[letterSpacing] 字距（px）；[averageEm] 平均字宽（em），
  /// 可用 [averageEm] 从台本正文估算；[padding] 为行内留白总和。
  /// 非法或过窄的输入返回 [minChars]，保证断行不会退化为 0。
  static int charsPerLine({
    required double width,
    required double fontSize,
    double letterSpacing = 0,
    double averageEm = wideEm,
    double padding = rowPadding,
  }) {
    if (!width.isFinite || !fontSize.isFinite || fontSize <= 0) return minChars;
    final usable = width - padding;
    if (!usable.isFinite || usable <= 0) return minChars;
    final advance = fontSize * averageEm.clamp(0.3, 1.2) * safety +
        (letterSpacing.isFinite ? letterSpacing : 0);
    if (advance <= 0) return maxChars;
    final chars = (usable / advance).floor();
    return chars.clamp(minChars, maxChars);
  }

  static bool _isWide(int rune) {
    return (rune >= 0x1100 && rune <= 0x115F) ||
        (rune >= 0x2E80 && rune <= 0xA4CF) ||
        (rune >= 0xAC00 && rune <= 0xD7A3) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0xFE30 && rune <= 0xFE6F) ||
        (rune >= 0xFF00 && rune <= 0xFF60) ||
        (rune >= 0xFFE0 && rune <= 0xFFE6) ||
        (rune >= 0x20000 && rune <= 0x3FFFD);
  }
}
