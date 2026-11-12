import 'dart:math' as math;

import 'normalizer.dart';
import 'script_index.dart';

/// 一次对齐的结果（§5.5 输出）。
class AlignResult {
  /// 创建对齐结果。
  const AlignResult({
    required this.anchorToken,
    required this.anchorLine,
    required this.confidence,
    required this.cost,
    required this.isFinal,
    this.anchorCharOffset = 0,
    this.spanLength = 0,
    this.spanCost = 0,
    this.matched = true,
    this.pending = false,
    this.reanchored = false,
    this.suggestedLine = -1,
  });

  /// 无位置变更的结果（未命中 / 证据不足）。
  ///
  /// 这类结果仍然要送到 UI：识别文本和解码耗时必须继续刷新，
  /// 否则「对不上台本」会被误认成「识别坏了」。位置由 [anchorLine] 原样带回。
  const AlignResult.hold({
    required this.anchorLine,
    this.anchorCharOffset = 0,
    this.isFinal = false,
    this.pending = false,
    this.suggestedLine = -1,
  })  : anchorToken = -1,
        confidence = 0,
        cost = 0,
        spanLength = 0,
        spanCost = 0,
        matched = false,
        reanchored = false;

  /// 命中的 token 下标。
  final int anchorToken;

  /// 命中的行号（段落化后即段落号）。
  final int anchorLine;

  /// 命中 token 在行文本内的字符偏移。
  ///
  /// 段落化后一行包含整段文字，阅读锚点需要下沉到段内字符才能连续跟随；
  /// 旧版按句切行时该值通常为 0。
  final int anchorCharOffset;

  /// 归一化置信度（0–1）。
  final double confidence;

  /// DP 路径代价。
  final double cost;

  /// 是否为最终结果。
  final bool isFinal;

  /// 置信度统计区间的长度（token 数，从首个命中算起）。
  final int spanLength;

  /// 置信度统计区间内的累计代价。
  final double spanCost;

  /// 是否真正命中台本。
  ///
  /// false 表示本次只用于刷新识别展示，不得作为位置推进依据。
  final bool matched;

  /// 证据不足（端点重置后只有 1–2 个音节）：等待，不当作零证据。
  final bool pending;

  /// 本条结果来自「失败重定位」路径。
  final bool reanchored;

  /// 重定位发现、但被 +3 行规则拒绝的候选行；-1 表示没有。
  ///
  /// 只用于日志/提示，调用方不得据此移动阅读位置。
  final int suggestedLine;

  AlignResult _asReanchored() => AlignResult(
        anchorToken: anchorToken,
        anchorLine: anchorLine,
        confidence: confidence,
        cost: cost,
        isFinal: isFinal,
        anchorCharOffset: anchorCharOffset,
        spanLength: spanLength,
        spanCost: spanCost,
        reanchored: true,
      );

  @override
  String toString() =>
      'AlignResult(line=$anchorLine, token=$anchorToken, conf=${confidence.toStringAsFixed(2)})';
}

/// 对齐性能计数：只在评测/诊断时打开，生产路径保持关闭（零额外开销）。
class AlignMetrics {
  /// 是否采集（默认关闭）。
  bool enabled = false;

  /// DP 总次数（锚点窗口 + 预筛 + 重锚）。
  int dpRuns = 0;

  /// DP 实际访问的格子数（受窗口 200 / 带宽 40 约束）。
  int dpCells = 0;

  /// 其中由预筛额外触发的 DP 次数。
  int prescreenDpRuns = 0;

  /// 重锚扫描（在 900 token 范围上做音节命中率滑窗）的次数。
  int reanchorScans = 0;

  /// 重锚扫描后再跑 DP 的次数。
  int reanchorDpRuns = 0;

  /// 累计 DP 耗时（微秒）。
  double dpMicros = 0;

  final Stopwatch _clock = Stopwatch();

  /// 清零计数。
  void reset() {
    dpRuns = 0;
    dpCells = 0;
    prescreenDpRuns = 0;
    reanchorScans = 0;
    reanchorDpRuns = 0;
    dpMicros = 0;
  }

  /// 序列化为报告字段。
  Map<String, Object?> toJson() => {
        'dpRuns': dpRuns,
        'dpCells': dpCells,
        'prescreenDpRuns': prescreenDpRuns,
        'reanchorScans': reanchorScans,
        'reanchorDpRuns': reanchorDpRuns,
        'dpMicros': (dpMicros * 10).round() / 10,
      };
}

/// 拼音音节命中率预筛 + 窗口单调 DP 精定位（§5.5 步骤 2）。
///
/// 口径（0.25.0 起）：对齐单位是**音节**——中文一字即一个音节，英文术语整体
/// 一个 token；比较用无声调拼音的模糊等价类，声调只作为同音/近音之间的
/// 微小加分（[toneMismatchCost]），不构成硬条件。
///
/// 代价与置信度也按音节重算：
/// - 替换/漏读（台本有、识别没有）/多读（识别有、台本没有）各记 1 个音节错误；
/// - 声调不同额外 +0.1，仅用于在多音字候选之间做稳定选择；
/// - `span` = 从首个命中音节到识别文本末尾的音节数；
/// - `confidence = 1 - spanError / (span × errorBudgetPerSyllable)`，即
///   **命中区间内的音节一致率**（1 = 每个音节都对上，0 = 完全对不上）。
class AlignEngine {
  /// 创建对齐引擎。
  AlignEngine(
    this.index, {
    this.windowW = 200,
    this.band = 40,
    this.matchCost = 0.0,
    this.subCost = 1.0,
    this.delCost = 1.0,
    this.insCost = 1.0,
    this.toneMismatchCost = 0.1,
    this.errorBudgetPerSyllable = 1.0,
    this.lookAheadLines = 3,
    this.minScore = 0.35,
    Normalizer normalizer = const Normalizer(),
  }) : _normalizer = normalizer;

  /// 台本索引。
  final ScriptIndex index;

  /// DP 窗口宽度（token 数）。
  final int windowW;

  /// 单调约束带宽（token 数）。
  final int band;

  /// 匹配代价。
  final double matchCost;

  /// 替换代价（1 个音节对不上）。
  final double subCost;

  /// 删除代价（台本有、识别漏读 1 个音节）。
  final double delCost;

  /// 插入代价（识别多出 1 个音节，如口头禅）。
  final double insCost;

  /// 声调不同的额外代价：只做加分项，不影响是否命中。
  final double toneMismatchCost;

  /// 每个音节允许的累计错误预算（置信度归零点），1.0 = 音节一致率。
  final double errorBudgetPerSyllable;

  /// 预筛向前看的行数。
  final int lookAheadLines;

  /// 预筛命中率下限（低于该值不额外跑窗口）。
  final double minScore;

  final Normalizer _normalizer;

  /// 诊断计数（默认关闭；评测用 `metrics.enabled = true` 打开）。
  final AlignMetrics metrics = AlignMetrics();

  /// 少于 3 个音节不构成证据：端点重置后的第一个 partial 记为「等待」，
  /// 不计入未命中次数，也不清零闸门的弱命中累计。
  static const int pendingMinSyllables = 3;

  /// 连续未命中多少次后尝试重定位。
  static const int reanchorAfterMisses = 3;

  /// 重定位向前扫描的 token 上限（约 900 个音节）。
  static const int reanchorScanTokens = 900;

  /// 重定位单次允许的最大跨行数，与其他三条通道共用同一红线。
  static const int reanchorMaxLeapLines = 3;

  /// 重定位接受的置信度下限。
  static const double reanchorMinConfidence = 0.5;

  /// 单次即确认的高置信度（否则要求同一落点连续两次）。
  static const double reanchorDirectConfidence = 0.8;

  /// 一次重定位确认后，必须先出现多少次正常命中才允许下一次重定位。
  ///
  /// 没有这道冷却，「卡住 → 重锚 3 行 → 又卡住 → 再重锚 3 行」会在几秒内
  /// 累积成十行以上的跳读；正常命中说明新窗口已经和朗读位置对上，才重新放行。
  static const int reanchorCooldownMatches = 3;

  int _missStreak = 0;
  int _reanchorLine = -1;
  int _reanchorHits = 0;
  int _reanchorCooldown = 0;

  /// 当前分句（utterance）的起点 token。端点后重设，分句内保持不变。
  ///
  /// ASR 文本是「本分句累积」的：端点前每次 partial 都在尾部追加，阅读位置
  /// 只落在文本末尾附近。若窗口跟着阅读位置滑动，文本前缀就落在窗口之前，
  /// 只能记为插入代价；更糟的是 DP 带宽 `|i-j| <= band`，当一条分句超过
  /// `band` 个音节（约 8 秒快速朗读）时，真实路径直接落到带宽之外，DP 只能
  /// 用「删掉台本前一段 + 把文本尾巴对到更后面」的假路径，锚点于是先于朗读
  /// 位置滑到后面几行，置信度掉到 0.2–0.3，滚行被冻结（zh_fast 实测
  /// 8.1 s 起连锁前跳、21.5 s 才靠端点新分句追回）。
  ///
  /// 以分句起点为窗口起点后，整条文本重新落在 DP 对角线附近，真实路径可达；
  /// 带宽只约束文本内部的局部错位，不再限制分句长度。
  int? _utteranceStartToken;

  /// 上一次 `align` 是否是端点结果：下一次调用属于新分句。
  bool _lastWasFinal = false;

  /// 上一次识别文本的音节序列（用于判断是否换分句）。
  List<String> _lastRaws = const <String>[];

  /// 对齐一段识别文本；[currentLine] 是当前锚点行。
  ///
  /// [currentCharOffset] 是锚点在该行内的字符偏移（阅读位置）。对齐窗口从
  /// 阅读位置附近开始，而不是从行首开始：识别按端点重置后，新 utterance 往往
  /// 从段落中间开始，从行首起算会把「行首到阅读位置」记成删除代价，DP 于是
  /// 选一条短而错的路径把锚点拉回行首（长段落卡住，读到下一段再猛跳）。
  AlignResult? align(
    String asrText, {
    required int currentLine,
    int currentCharOffset = 0,
    bool isFinal = false,
  }) {
    final asr = _normalizer.normalize(asrText);
    if (asr.isEmpty) return null;

    final raws = [for (final t in asr) t.raw];
    final common = _commonPrefix(raws, _lastRaws);
    // 换分句的判定：端点（显式）或文本与上次几乎没有公共前缀（识别重置、
    // 或调用方换了朗读位置）。同一分句内 partial 只会在尾部追加/小改，
    // 公共前缀仍然很长。
    final newUtterance = _lastWasFinal ||
        _lastRaws.isEmpty ||
        common < math.max(3, (_lastRaws.length * 0.5).floor());
    _lastWasFinal = isFinal;

    if (asr.length < pendingMinSyllables) {
      return AlignResult.hold(
        anchorLine: currentLine,
        anchorCharOffset: currentCharOffset,
        isFinal: isFinal,
        pending: true,
      );
    }
    _lastRaws = raws;

    final lineStart = index.startTokenOfLine(currentLine);
    var hint = index.tokenAtOrAfter(currentLine, currentCharOffset);
    // 字符偏移必须属于 [currentLine] 行。调用方可能在跟踪器已内部前移、而
    // 阅读位置还没跟上时沿用上一行的偏移；`tokenAtOrAfter` 越界会返回
    // **下一行行首**，窗口于是整体越过当前行，DP 只能去更后面找词，
    // 表现为「低置信但一直往前跳」。越界即视为过期偏移，退回行首。
    if (hint >= index.endTokenOfLine(currentLine)) hint = lineStart;
    if (newUtterance || _utteranceStartToken == null) {
      _utteranceStartToken = hint;
    } else if (hint - _utteranceStartToken! > asr.length * 1.5 + 10) {
      // 阅读位置已经远远越过「分句起点 + 文本长度」能解释的范围：说明
      // 调用方换了朗读位置（手动跳行/断点续读），旧分句起点作废。
      _utteranceStartToken = hint;
    }
    final anchorResult = _runDp(
      asr,
      _utteranceStartToken!,
      isFinal: isFinal,
    );

    final preLine = _prescreenLine(asr, currentLine);
    AlignResult? preResult;
    if (preLine != null) {
      if (metrics.enabled) metrics.prescreenDpRuns++;
      preResult = _runDp(
        asr,
        index.startTokenOfLine(preLine),
        isFinal: isFinal,
      );
    }

    final best = _pick(anchorResult, preResult);
    if (best != null) {
      _missStreak = 0;
      _clearReanchor();
      if (_reanchorCooldown > 0) _reanchorCooldown--;
      return best;
    }

    // 窗口内没有任何命中：连续失败到阈值后做一次更大范围的重定位。
    _missStreak++;
    if (_missStreak >= reanchorAfterMisses) {
      final re = _tryReanchor(
        asr,
        currentLine: currentLine,
        currentCharOffset: currentCharOffset,
        isFinal: isFinal,
      );
      if (re != null) return re;
    }

    return AlignResult.hold(
      anchorLine: currentLine,
      anchorCharOffset: currentCharOffset,
      isFinal: isFinal,
    );
  }

  /// 预筛接管的置信度下限。
  static const double _prescreenTakeoverFloor = 0.5;

  /// 预筛接管需要的置信优势（相对锚点窗口结果）。
  static const double _prescreenTakeoverMargin = 0.2;

  /// 锚点窗口有结果时优先使用；预筛只在「显著更优」时才接管。
  ///
  /// 之前允许预筛以 +0.1 的置信优势覆盖锚点结果，快速朗读时会出现
  /// 「0→1→2→3」的低置信连锁前跳：每一次都只是「下一行看起来稍好」，
  /// 但几次叠加后锚点已经冲到尚未读到的段落，随后再也匹配不上。
  ///
  /// 现在要求预筛同时满足「自身置信 ≥0.5」和「比锚点高 ≥0.2」才接管：
  /// 真正跨行的高置信证据仍能前移，而 +0.1 的低置信抖动不再驱动滚动。
  AlignResult? _pick(AlignResult? anchorResult, AlignResult? preResult) {
    if (anchorResult == null) return preResult;
    if (preResult == null) return anchorResult;
    if (preResult.confidence >= _prescreenTakeoverFloor &&
        preResult.confidence >
            anchorResult.confidence + _prescreenTakeoverMargin) {
      return preResult;
    }
    return anchorResult;
  }

  void _clearReanchor() {
    _reanchorLine = -1;
    _reanchorHits = 0;
  }

  /// 失败重定位：只在正常窗口之外向前扫描，命中后仍受 +3 行硬约束。
  ///
  /// 防跳规则：
  /// - 只允许落在当前行之后（不后退）；
  /// - 落点超过 `currentLine + reanchorMaxLeapLines` 时**不改变位置**，
  ///   只把候选行放进 [AlignResult.suggestedLine] 供展示/日志；
  /// - 除单次高置信（≥0.8）外，同一落点需要连续两次才能确认，
  ///   避免一次偶然同音就把整页翻过去。
  AlignResult? _tryReanchor(
    List<NormToken> asr, {
    required int currentLine,
    required int currentCharOffset,
    required bool isFinal,
  }) {
    if (index.tokenCount == 0) return null;
    // 冷却期：上一次重锚之后还没重新和朗读位置对上，不再允许第二次跳。
    if (_reanchorCooldown > 0) return null;
    if (metrics.enabled) metrics.reanchorScans++;
    final from = index.startTokenOfLine(currentLine) + windowW;
    final to = math.min(index.tokenCount, from + reanchorScanTokens);
    if (to - from < asr.length) return null;

    final spokenKeys = <String>{for (final token in asr) ...token.readings};
    final span = math.max(asr.length, 6);
    int? bestStart;
    var bestScore = 0.0;
    for (var p = from; p + span <= to; p++) {
      var hit = 0;
      for (var q = p; q < p + span; q++) {
        if (index.tokens[q].readings.any(spokenKeys.contains)) hit++;
      }
      final score = hit / span;
      if (score > bestScore) {
        bestScore = score;
        bestStart = p;
      }
    }
    if (bestStart == null || bestScore < minScore) return null;

    final result = _runDp(asr, bestStart, isFinal: isFinal);
    if (metrics.enabled) metrics.reanchorDpRuns++;
    if (result == null || result.confidence < reanchorMinConfidence) {
      return null;
    }
    final line = result.anchorLine;
    // 不后退：重定位只解决「卡在已读位置」，不负责回看。
    if (line <= currentLine) return null;
    if (line > currentLine + reanchorMaxLeapLines) {
      return AlignResult.hold(
        anchorLine: currentLine,
        anchorCharOffset: currentCharOffset,
        isFinal: isFinal,
        suggestedLine: line,
      );
    }
    if (result.confidence >= reanchorDirectConfidence) {
      _clearReanchor();
      _reanchorCooldown = reanchorCooldownMatches;
      return result._asReanchored();
    }
    if (_reanchorLine == line) {
      _reanchorHits++;
    } else {
      _reanchorLine = line;
      _reanchorHits = 1;
    }
    if (_reanchorHits >= 2) {
      _clearReanchor();
      _reanchorCooldown = reanchorCooldownMatches;
      return result._asReanchored();
    }
    return AlignResult.hold(
      anchorLine: currentLine,
      anchorCharOffset: currentCharOffset,
      isFinal: isFinal,
      suggestedLine: line,
    );
  }

  /// 命中率预筛：只向前看 [currentLine, currentLine+lookAhead]。
  ///
  /// 不再回看 currentLine-2：预筛到后方行会制造「锚点回跳」的对齐起点，
  /// 与「锚点单调不后退」冲突（P3 回跳）。
  int? _prescreenLine(List<NormToken> asr, int currentLine) {
    final from = math.max(0, currentLine);
    final to = math.min(index.lineCount - 1, currentLine + lookAheadLines);
    int? bestLine;
    var bestScore = 0.0;
    for (var line = from; line <= to; line++) {
      final keys = index.lineKeys[line];
      if (keys.isEmpty) continue;
      var hit = 0;
      for (final token in asr) {
        // 多音字/近音字按候选读音集合求交，预筛与 DP 口径一致。
        if (token.readings.any(keys.contains)) hit++;
      }
      final score = hit / asr.length;
      if (score > bestScore) {
        bestScore = score;
        bestLine = line;
      }
    }
    if (bestLine == null || bestScore < minScore) return null;
    if (bestLine == currentLine) {
      // 与当前锚点一致，不必额外跑一次窗口。
      return null;
    }
    return bestLine;
  }

  static int _commonPrefix(List<String> a, List<String> b) {
    final n = math.min(a.length, b.length);
    var i = 0;
    while (i < n && a[i] == b[i]) {
      i++;
    }
    return i;
  }

  AlignResult? _runDp(
    List<NormToken> asr,
    int startToken, {
    required bool isFinal,
  }) {
    if (index.tokenCount == 0 || asr.isEmpty) return null;
    final sw = metrics.enabled
        ? (metrics._clock
          ..reset()
          ..start())
        : null;
    try {
      return _runDpInner(asr, startToken, isFinal: isFinal);
    } finally {
      if (sw != null) {
        sw.stop();
        metrics.dpRuns++;
        metrics.dpMicros += sw.elapsedMicroseconds;
      }
    }
  }

  AlignResult? _runDpInner(
    List<NormToken> asr,
    int startToken, {
    required bool isFinal,
  }) {
    if (index.tokenCount == 0 || asr.isEmpty) return null;

    final m = asr.length;

    final start = startToken < 0 ? 0 : startToken;
    // 长分句（> windowW）必须把窗口放长到能覆盖整条文本，否则真实路径落到
    // 窗口之外；带宽已经把访问格子数限制在 m × (2·band+1)，放长窗口不增加
    // 实际 DP 计算量。上限 600 音节（约 2 分钟不停顿）防止异常输入吃内存。
    final reachable = math.min(index.tokenCount - start, 600);
    final n = math.min(reachable, math.max(windowW, m + 2 * band));
    if (n <= 0) return null;
    final cols = n + 1;
    final dp = List<double>.filled((m + 1) * cols, double.infinity);
    final lastMatch = List<int>.filled((m + 1) * cols, -1);
    // 路径上「第一次命中」的位置与命中前代价：置信度只统计首个命中之后的区间。
    final firstCost = List<double>.filled((m + 1) * cols, -1);
    final firstJ = List<int>.filled((m + 1) * cols, -1);

    dp[0] = 0;
    // 台本前缀**免费跳过**：识别文本的起点未必正好落在窗口起点（提前跨行、
    // 手动跳行、或分句起点估计偏早）。若给前缀记删除代价，DP 会改选
    // 「跳过文本前缀、只把尾巴对到更后面」的假路径——尾巴路径的插入代价
    // 更小，锚点因此不随说话前进（实测「我们把音频流交给」停在行内第 7 字）。
    // 免费跳过只影响起点，文本本身仍必须逐音节消费；带宽 40 仍把起点限制在
    // 窗口起点后 40 个音节内，不会凭空跳到很远。
    for (var i = 1; i <= n; i++) {
      dp[i] = 0;
    }
    for (var j = 1; j <= m; j++) {
      dp[j * cols] = j * insCost;
    }

    var cells = 0;
    for (var j = 1; j <= m; j++) {
      for (var i = 1; i <= n; i++) {
        if ((i - j).abs() > band) continue;
        cells++;
        var best = double.infinity;
        var bestLast = -1;
        var bestFirstCost = -1.0;
        var bestFirstJ = -1;
        final diagIndex = (j - 1) * cols + (i - 1);
        final upIndex = (j - 1) * cols + i;
        final leftIndex = j * cols + (i - 1);

        final skipAsr = dp[upIndex] + insCost;
        if (skipAsr < best) {
          best = skipAsr;
          bestLast = lastMatch[upIndex];
          bestFirstCost = firstCost[upIndex];
          bestFirstJ = firstJ[upIndex];
        }
        final skipScript = dp[leftIndex] + delCost;
        if (skipScript < best) {
          best = skipScript;
          bestLast = lastMatch[leftIndex];
          bestFirstCost = firstCost[leftIndex];
          bestFirstJ = firstJ[leftIndex];
        }
        final scriptToken = index.tokens[start + i - 1];
        final spokenToken = asr[j - 1];
        final same = scriptToken.matches(spokenToken);
        // 读音命中即等价；声调相同额外减 0.1，作为多音字消歧的加分项。
        final toneMatched = same &&
            scriptToken.tone != 0 &&
            scriptToken.tone == spokenToken.tone;
        final substitute = dp[diagIndex] +
            (same
                ? (toneMatched ? matchCost : matchCost + toneMismatchCost)
                : subCost);
        if (substitute < best) {
          best = substitute;
          // 锚点只能落在真正命中的 token 上：末尾未命中的替换（识别尾字
          // 被硬对齐到本行最后一个 token）会把阅读锚点推到行尾，随后整行
          // 语音都"在锚点后面"，不再推进（D2）。
          bestLast = same ? start + i - 1 : lastMatch[diagIndex];
          if (same && firstJ[diagIndex] < 0) {
            // 这是路径上的第一次命中，记录命中前的代价与位置。
            bestFirstCost = dp[diagIndex];
            bestFirstJ = j;
          } else {
            bestFirstCost = firstCost[diagIndex];
            bestFirstJ = firstJ[diagIndex];
          }
        }

        final cell = j * cols + i;
        dp[cell] = best;
        lastMatch[cell] = bestLast;
        firstCost[cell] = bestFirstCost;
        firstJ[cell] = bestFirstJ;
      }
    }

    var bestCost = double.infinity;
    var bestI = -1;
    if (metrics.enabled) metrics.dpCells += cells;
    for (var i = 0; i <= n; i++) {
      final cost = dp[m * cols + i];
      if (cost < bestCost) {
        bestCost = cost;
        bestI = i;
      }
    }
    if (bestI < 0) return null;
    final endCell = m * cols + bestI;
    final last = lastMatch[endCell];
    if (last < 0) return null;

    // 只统计首个命中之后的对齐质量：长 utterance 里「命中之前」的识别文本
    // 是已经读过的上下文，不该按插入/替换惩罚（否则置信度会被压到 0.2–0.4）。
    final fj = firstJ[endCell];
    final span = fj < 0 ? 0 : m - fj + 1;
    final spanError = fj < 0 ? double.infinity : bestCost - firstCost[endCell];
    // 少于 3 个音节不算证据：单个尾字很容易与前方段落偶然同音
    // （如「说/所」suo），若给满分会让跟踪器逐条向前棘轮式误跳。
    final confidence = span < 3 || spanError.isInfinite
        ? 0.0
        : (1 - spanError / (span * errorBudgetPerSyllable)).clamp(0.0, 1.0);
    final anchorLine = index.lineOfToken(last);
    return AlignResult(
      anchorToken: last,
      anchorLine: anchorLine,
      anchorCharOffset: index.tokens[last].srcStart,
      confidence: confidence,
      cost: bestCost,
      isFinal: isFinal,
      spanLength: span,
      spanCost: spanError,
    );
  }
}
