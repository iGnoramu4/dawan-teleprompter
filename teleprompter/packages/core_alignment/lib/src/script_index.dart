import 'normalizer.dart';

/// 台本的预编译索引：token 流 + token→行 映射 + 每行模糊 key 集合。
///
/// 纯 Dart，无 Flutter 依赖（§8 约束）。
class ScriptIndex {
  ScriptIndex._({
    required this.tokens,
    required this.lineStarts,
    required this.lineKeys,
  });

  /// 全台本 token 流。
  final List<NormToken> tokens;

  /// 每行第一个 token 的下标（长度 = lineCount）。
  final List<int> lineStarts;

  /// 每行的模糊 key 集合，用于命中率预筛。
  ///
  /// 收录该行所有 token 的全部候选读音，多音字在预筛阶段也不会被漏掉。
  final List<Set<String>> lineKeys;

  /// token 总数。
  int get tokenCount => tokens.length;

  /// 行数。
  int get lineCount => lineStarts.length;

  /// 从各行文本构建索引。
  ///
  /// 台本不参与拉丁术语合并：合并只针对识别输出被拆开的词（`I PHONE`），
  /// 若台本也合并会改变 token 数与偏移，导致 `line_step` 候选行误判（D1）。
  factory ScriptIndex.build(
    List<String> lines, {
    Normalizer normalizer = const Normalizer(mergeLatinTerms: false),
  }) {
    final tokens = <NormToken>[];
    final lineStarts = <int>[];
    final lineKeys = <Set<String>>[];

    for (final line in lines) {
      lineStarts.add(tokens.length);
      final lineTokens = normalizer.normalize(line);
      tokens.addAll(lineTokens);
      lineKeys.add(<String>{
        for (final token in lineTokens) ...token.readings,
      });
    }

    return ScriptIndex._(
        tokens: tokens, lineStarts: lineStarts, lineKeys: lineKeys);
  }

  /// 某行第一个 token 的下标。
  int startTokenOfLine(int line) {
    if (lineCount == 0) return 0;
    return lineStarts[clampLine(line)];
  }

  /// 某行最后一个 token 的下一个下标。
  int endTokenOfLine(int line) {
    if (lineCount == 0) return 0;
    final next = clampLine(line) + 1;
    return next >= lineCount ? tokens.length : lineStarts[next];
  }

  /// 把行号限制在 `[0, lineCount - 1]`。
  int clampLine(int line) {
    if (lineCount == 0) return 0;
    if (line < 0) return 0;
    if (line >= lineCount) return lineCount - 1;
    return line;
  }

  /// 行内字符偏移 → 该行内第一个 `srcStart >= charOffset` 的 token 下标（二分）。
  ///
  /// 用于把对齐窗口钉在「当前读到哪」，而不是钉在行首：长段落里识别按端点
  /// 反复重置，若窗口始终从行首开始，行首前缀的删除代价会让 DP 选一条短而
  /// 错的路径，锚点卡在行首附近（长段落卡住、跨段后猛跳）。
  int tokenAtOrAfter(int line, int charOffset) {
    if (tokenCount == 0) return 0;
    final start = startTokenOfLine(line);
    final end = endTokenOfLine(line);
    if (charOffset <= 0 || start >= end) return start;
    var lo = start;
    var hi = end;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (tokens[mid].srcStart < charOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// token 下标 → 行号（二分查找）。
  int lineOfToken(int tokenIndex) {
    if (lineCount == 0) return 0;
    var lo = 0;
    var hi = lineCount - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= tokenIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}
