import 'dart:math' as math;

/// 标注中的一行（对应台本的一个语义行/段落）。
class LabelLine {
  const LabelLine({
    required this.index,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.spoken = true,
  });

  factory LabelLine.fromJson(Map<String, dynamic> json) => LabelLine(
        index: json['index'] as int,
        text: json['text'] as String,
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
        spoken: json['spoken'] as bool? ?? true,
      );

  final int index;
  final String text;
  final int startMs;
  final int endMs;

  /// 该行是否真的被读出（跳读段里为 false）。
  final bool spoken;

  Map<String, Object?> toJson() => {
        'index': index,
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
        'spoken': spoken,
      };
}

/// 一个评测片段的标注。
class SegmentLabel {
  const SegmentLabel({
    required this.id,
    required this.lines,
    required this.durationMs,
  });

  factory SegmentLabel.fromJson(Map<String, dynamic> json) => SegmentLabel(
        id: json['id'] as String,
        lines: (json['lines'] as List<dynamic>)
            .map((e) => LabelLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        durationMs: json['durationMs'] as int,
      );

  final String id;
  final List<LabelLine> lines;
  final int durationMs;

  List<LabelLine> get spokenLines => lines.where((l) => l.spoken).toList();

  /// 无语音区间（含段首段尾），只保留 ≥ 600 ms 的。
  List<List<int>> silenceSpans(int minMs) {
    final spans = <List<int>>[];
    var cursor = 0;
    for (final line in lines) {
      if (line.startMs - cursor >= minMs) {
        spans.add([cursor, line.startMs]);
      }
      cursor = math.max(cursor, line.endMs);
    }
    if (durationMs - cursor >= minMs) {
      spans.add([cursor, durationMs]);
    }
    return spans;
  }

  /// t 时刻应该读到的行；无语音时为最后一句已读行（没有则为 -1）。
  int groundTruthLineAt(int t) {
    var gt = -1;
    for (final line in spokenLines) {
      if (line.startMs <= t) {
        gt = line.index;
      } else {
        break;
      }
    }
    return gt;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'lines': lines.map((l) => l.toJson()).toList(),
        'durationMs': durationMs,
      };
}

/// 一次滚动位置变化。
class ScrollEvent {
  const ScrollEvent({
    required this.audioMs,
    required this.line,
    required this.charOffset,
    required this.confidence,
    required this.reason,
  });

  final int audioMs;
  final int line;
  final int charOffset;
  final double confidence;

  /// `same_line` / `line_step` / `early_arm`。
  final String reason;
}

/// 统计量的简单封装。
class Stats {
  const Stats({required this.values});

  final List<double> values;

  int get count => values.length;
  double get mean =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
  double get p50 => percentile(50);
  double get p95 => percentile(95);
  double get max => values.isEmpty ? 0 : values.reduce(math.max);

  double percentile(double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final idx = ((p / 100) * (sorted.length - 1)).round();
    return sorted[idx];
  }

  Map<String, Object?> toJson() => {
        'count': count,
        'mean': _r(mean),
        'p50': _r(p50),
        'p95': _r(p95),
        'max': _r(max),
      };
}

double _r(double v) => (v * 10).roundToDouble() / 10;

/// 单段评测结果。
class SegmentMetrics {
  SegmentMetrics({
    required this.id,
    required this.category,
    required this.durationMs,
    required this.cer,
    required this.distance,
    required this.refTokens,
    required this.reference,
    required this.hypothesis,
    required this.firstCharLatency,
    required this.firstCharMiss,
    required this.followLatency,
    required this.followMiss,
    required this.hitRate,
    required this.hitLines,
    required this.spokenLines,
    required this.falseTriggers,
    required this.silenceMinutes,
    required this.maxOverAdvance,
    required this.rtf,
    required this.decodeMs,
    required this.loadMs,
    required this.utterances,
  });

  final String id;
  final String category;
  final int durationMs;
  final double cer;
  final int distance;
  final int refTokens;
  final String reference;
  final String hypothesis;
  final Stats firstCharLatency;
  final int firstCharMiss;
  final Stats followLatency;
  final int followMiss;
  final double hitRate;
  final int hitLines;
  final int spokenLines;
  final int falseTriggers;
  final double silenceMinutes;
  final int maxOverAdvance;
  final double rtf;
  final double decodeMs;
  final double loadMs;
  final List<String> utterances;

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category,
        'durationMs': durationMs,
        'cer': _r(cer),
        'distance': distance,
        'refTokens': refTokens,
        'reference': reference,
        'hypothesis': hypothesis,
        'firstCharLatency': firstCharLatency.toJson(),
        'firstCharMiss': firstCharMiss,
        'followLatency': followLatency.toJson(),
        'followMiss': followMiss,
        'hitRate': _r(hitRate),
        'hitLines': hitLines,
        'spokenLines': spokenLines,
        'falseTriggers': falseTriggers,
        'silenceMinutes': _r(silenceMinutes),
        'falseTriggerPerMin':
            _r(silenceMinutes <= 0 ? 0 : falseTriggers / silenceMinutes),
        'maxOverAdvance': maxOverAdvance,
        'rtf': rtf,
        'decodeMs': _r(decodeMs),
        'loadMs': _r(loadMs),
        'utterances': utterances,
      };
}

/// 由标注、ASR 事件与滚动事件计算指标。
SegmentMetrics computeMetrics({
  required String id,
  required String category,
  required SegmentLabel label,
  required List<AsrEventLike> asrEvents,
  required List<ScrollEvent> scrollEvents,
  required double rtf,
  required double decodeMs,
  required double loadMs,
  required List<String> utterances,
  required String hypothesis,
  required double cer,
  required int distance,
  required int refTokens,
  required String reference,
  int hitGraceMs = 600,
}) {
  final firstChar = <double>[];
  var firstCharMiss = 0;
  final follow = <double>[];
  var followMiss = 0;

  for (final line in label.spokenLines) {
    final firstAsr = asrEvents
        .where(
            (e) => e.audioMs >= line.startMs && e.audioMs <= line.endMs + 2000)
        .toList();
    if (firstAsr.isEmpty) {
      firstCharMiss++;
    } else {
      firstChar.add((firstAsr.first.audioMs - line.startMs).toDouble());
    }

    final reached = scrollEvents
        .where((e) => e.audioMs >= line.startMs && e.line >= line.index)
        .toList();
    if (reached.isEmpty) {
      followMiss++;
    } else {
      follow.add((reached.first.audioMs - line.startMs).toDouble());
    }
  }

  var hitLines = 0;
  for (final line in label.spokenLines) {
    final anchor = anchorAt(scrollEvents, line.endMs + hitGraceMs);
    if (anchor >= line.index) hitLines++;
  }

  final silences = label.silenceSpans(600);
  var silenceMs = 0;
  var falseTriggers = 0;
  for (final span in silences) {
    silenceMs += span[1] - span[0];
    final gt = label.groundTruthLineAt(span[0]);
    for (final e in scrollEvents) {
      if (e.audioMs >= span[0] &&
          e.audioMs < span[1] &&
          e.line > gt &&
          e.reason != 'same_line') {
        falseTriggers++;
      }
    }
  }

  var maxOverAdvance = 0;
  for (final e in scrollEvents) {
    final gt = label.groundTruthLineAt(e.audioMs);
    final over = e.line - gt;
    if (over > maxOverAdvance) maxOverAdvance = over;
  }

  final spoken = label.spokenLines.length;
  return SegmentMetrics(
    id: id,
    category: category,
    durationMs: label.durationMs,
    cer: cer,
    distance: distance,
    refTokens: refTokens,
    reference: reference,
    hypothesis: hypothesis,
    firstCharLatency: Stats(values: firstChar),
    firstCharMiss: firstCharMiss,
    followLatency: Stats(values: follow),
    followMiss: followMiss,
    hitRate: spoken == 0 ? 1 : hitLines / spoken,
    hitLines: hitLines,
    spokenLines: spoken,
    falseTriggers: falseTriggers,
    silenceMinutes: silenceMs / 60000.0,
    maxOverAdvance: maxOverAdvance,
    rtf: rtf,
    decodeMs: decodeMs,
    loadMs: loadMs,
    utterances: utterances,
  );
}

/// 取 t 时刻及之前的最后一个锚点行。
int anchorAt(List<ScrollEvent> events, int t) {
  var line = 0;
  for (final e in events) {
    if (e.audioMs > t) break;
    line = e.line;
  }
  return line;
}

/// 只暴露指标需要的字段，避免与 asr_runner 循环依赖。
class AsrEventLike {
  const AsrEventLike({required this.audioMs, required this.text});
  final int audioMs;
  final String text;
}
