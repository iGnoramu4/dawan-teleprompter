import 'package:core_alignment/core_alignment.dart';

import 'metrics.dart';

/// 一条「对齐命中」的时间线记录（评测延迟分解用）。
class AlignTimelineEvent {
  const AlignTimelineEvent({
    required this.ms,
    required this.line,
    required this.confidence,
    required this.trackerLine,
  });

  final int ms;
  final int line;
  final double confidence;
  final int trackerLine;
}

/// 复刻 `reader_page.dart` 0.22.0 的推进逻辑（默认 `lineStepFollow=true`）。
///
/// 输入是 ASR 事件流，输出是「锚点行/段内字符」变化事件，用于计算跟随延迟
/// 与误触发。不依赖 Flutter，也不改产品代码。
class FollowSimulator {
  FollowSimulator({
    required this.lines,
    MatchProfile profile = MatchProfile.standardProfile,
    int initialLine = 0,
    this.latencyCompensation = false,
    this.lineCoverage = true,
    this.chunkMs = 20,
  })  : index = ScriptIndex.build(lines),
        _normalizer = const Normalizer(),
        tracker = AlignTracker.fromProfile(profile, lineCount: lines.length) {
    _aligner = AlignEngine(
      index,
      lookAheadLines: profile.lookAheadLines,
      minScore: profile.weakConfidence,
      normalizer: _normalizer,
    );
    // 评测需要 DP 耗时/次数分解；真机不走这个类，开销只落在评测里。
    _aligner.metrics.enabled = true;
    _gate = LineStepGate.fromProfile(profile);
    _earlyArm = EarlyArmDetector.fromProfile(index, profile);
    _coverage = LineCoverageTracker(index);
    _line = initialLine;
  }

  /// 是否开启端到端延迟补偿（对照实验用）。
  ///
  /// 补偿把滚动目标提前「采集分片 + 解码 + 一帧」的时延；在事件流上等价于
  /// 滚动事件时间戳提前同样的量，因此这里按该口径记账（上限 400 ms）。
  final bool latencyCompensation;

  /// 是否开启行级覆盖率放行（关闭即为 0.26.0 的逐行闸门口径）。
  final bool lineCoverage;

  /// 采集分片大小（ms），用于补偿估计。
  final int chunkMs;

  late final LineCoverageTracker _coverage;

  final Normalizer _normalizer;

  final List<String> lines;
  final ScriptIndex index;
  final AlignTracker tracker;
  late final AlignEngine _aligner;
  late final LineStepGate _gate;
  late final EarlyArmDetector _earlyArm;

  late int _line;
  int _char = 0;
  final AutoAdvanceBudget _budget = AutoAdvanceBudget();
  final List<ScrollEvent> events = <ScrollEvent>[];

  /// 每次 `align()` 的墙钟耗时（微秒），用于对齐段预算。
  final List<double> alignUs = <double>[];

  /// 相邻两条 ASR 文本更新的音频时间间隔（ms）。
  final List<int> asrGapsMs = <int>[];

  /// 命中事件时间线：用来拆分「ASR 跨行证据」与「闸门放行」两段等待。
  final List<AlignTimelineEvent> matchedEvents = <AlignTimelineEvent>[];

  int _lastAsrAtMs = -1;

  /// 对齐器内部的 DP 次数/耗时/扫描量。
  AlignMetrics get alignMetrics => _aligner.metrics;

  /// 逐条对齐诊断（仅在评测 dump 时使用）。
  void Function(String log)? trace;

  int get line => _line;
  int get charOffset => _char;

  void _advance(
      int line, int charOffset, int atMs, double confidence, String reason) {
    // 与真机同一个入口夹累计跳行：10 秒内跳行总和超过 3 行后退化为逐行。
    final target = _budget.limit(from: _line, to: line, nowMs: atMs);
    final offset = target == line ? charOffset : 0;
    _line = target;
    _char = offset;
    events.add(ScrollEvent(
      audioMs: atMs,
      line: target,
      charOffset: offset,
      confidence: confidence,
      reason: reason,
    ));
  }

  /// 处理一条 ASR 结果。
  void onAsr({
    required int audioMs,
    required String text,
    required bool isFinal,
    double decodeMs = 0,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final atMs = _compensated(audioMs, decodeMs);
    if (_lastAsrAtMs >= 0) asrGapsMs.add(atMs - _lastAsrAtMs);
    _lastAsrAtMs = atMs;

    // `_char` 只属于 `_line`；跟踪器可能已内部前移，混用会把窗口推到下一行。
    final alignClock = Stopwatch()..start();
    final align = _aligner.align(
      trimmed,
      currentLine: tracker.line,
      currentCharOffset: tracker.line == _line ? _char : 0,
      isFinal: isFinal,
    );
    alignUs.add(alignClock.elapsedMicroseconds.toDouble());
    if (align == null) return;
    // 未命中/等待只刷新展示，不能作为位置推进证据（与真机链路同口径）。
    if (!align.matched) return;

    trace?.call('  align ${atMs}ms tracker=${tracker.line} '
        'cand=${align.anchorLine} char=${align.anchorCharOffset} '
        'token=${align.anchorToken} conf=${align.confidence.toStringAsFixed(2)} '
        'cost=${align.cost.toStringAsFixed(1)} '
        'span=${align.spanLength}/${align.spanCost.toStringAsFixed(1)} text="${trimmed.length > 36 ? trimmed.substring(trimmed.length - 36) : trimmed}"');

    final candidate = tracker
        .update(
          candidateLine: align.anchorLine,
          rawConfidence: align.confidence,
          isFinal: isFinal,
        )
        .line
        .clamp(0, lines.length - 1);

    matchedEvents.add(AlignTimelineEvent(
      ms: atMs,
      line: align.anchorLine,
      confidence: align.confidence,
      trackerLine: tracker.line,
    ));

    final alignLine = align.anchorLine.clamp(0, lines.length - 1);
    final alignChar = align.anchorCharOffset < 0 ? 0 : align.anchorCharOffset;

    if (alignLine == _line) {
      if (alignChar > _char || (isFinal && alignChar != _char)) {
        _advance(_line, alignChar, atMs, align.confidence, 'same_line');
      }
      // 行级覆盖只在「对齐已跨行」时决定放行，行内不滚行：
      // 句末停顿里滚行会变成抢行（静音守线），只在行内记覆盖。
      if (lineCoverage) _coverage.update(_line, _normalizer.normalize(trimmed));
      return;
    }

    // 行级覆盖率放行：当前行整行覆盖达标时，越过闸门的逐字连续命中/弱命中
    // 累计要求直接放行（对齐已出现下一行读音证据，不会在静音里抢行）。
    if (lineCoverage && _line + 1 < lines.length) {
      final cover = _coverage.update(_line, _normalizer.normalize(trimmed));
      if (align.confidence >= _gate.effectiveWeak &&
          _coverage.allowsAdvance(cover)) {
        final target = alignLine < _line + maxAutoLeapLines
            ? alignLine
            : _line + maxAutoLeapLines;
        _advance(target, target == alignLine ? alignChar : 0, atMs,
            align.confidence, 'line_coverage');
        return;
      }
    }

    final decision = _gate.evaluate(
      currentLine: _line,
      candidateLine: candidate,
      confidence: align.confidence,
      isFinal: isFinal,
    );
    if (!decision.advanced) {
      final arm = _earlyArm.evaluate(
        currentLine: _line,
        anchorToken: align.anchorToken,
        spoken: _normalizer.normalize(trimmed),
        isFinal: isFinal,
      );
      if (arm.armed) {
        _advance(arm.line, 0, atMs, align.confidence, 'early_arm');
      }
      return;
    }
    _advance(
      decision.line,
      decision.line == alignLine ? alignChar : 0,
      atMs,
      align.confidence,
      'line_step',
    );
  }

  /// 端到端延迟补偿：事件时间提前「分片 + 解码 + 一帧」，最多 400 ms。
  int _compensated(int audioMs, double decodeMs) {
    if (!latencyCompensation) return audioMs;
    final lead = (chunkMs + decodeMs + 16.7).clamp(0.0, 400.0);
    return (audioMs - lead).round().clamp(0, audioMs);
  }
}
