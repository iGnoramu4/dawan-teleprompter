import 'dart:convert';

/// 单个时间轴采样点（§9.3）：`t` 为录制开始后的毫秒数，`anchor` 为行号。
///
/// v2 起增加 `char`（行内字符偏移），用于段落化后的连续回放；v1 数据
/// 没有该字段，按 0 处理并保持行级回放。
class TimelineSample {
  /// 创建采样点。
  const TimelineSample({
    required this.t,
    required this.anchor,
    this.char = 0,
    this.conf = 0,
  });

  /// 相对录制开始的毫秒数。
  final int t;

  /// 当前行号（从 0 开始；段落化后即段落号）。
  final int anchor;

  /// 当前行内的字符偏移（从 0 开始）。
  final int char;

  /// 语音跟随置信度（0–1，可选）。
  final double conf;

  /// 从 JSON 读取；字段缺失时抛 [FormatException]。
  factory TimelineSample.fromJson(Map<String, Object?> json) {
    final t = json['t'];
    final anchor = json['anchor'];
    if (t is! num || anchor is! num) {
      throw const FormatException('时间轴采样缺少 t/anchor');
    }
    return TimelineSample(
      t: t.toInt(),
      anchor: anchor.toInt(),
      char: ((json['char'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
      conf: (json['conf'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 序列化为 JSON（`char`/`conf` 为 0 时省略）。
  Map<String, Object?> toJson() => {
        't': t,
        'anchor': anchor,
        if (char != 0) 'char': char,
        if (conf != 0) 'conf': conf,
      };
}

/// 录制时间轴（§9.3 `timeline.json` / `recordings.timeline_json`）。
class RecordingTimeline {
  /// 创建时间轴。
  const RecordingTimeline({
    required this.scriptId,
    required this.durationMs,
    required this.samples,
    this.version = formatVersion,
  });

  /// 当前支持的时间轴格式版本（v2 增加行内字符偏移）。
  static const int formatVersion = 2;

  /// 仍可读取的最旧版本（v1：只有行号）。
  static const int minSupportedVersion = 1;

  /// 格式版本。
  final int version;

  /// 所属台本 id。
  final String scriptId;

  /// 录制总时长（毫秒）。
  final int durationMs;

  /// 采样序列（按时间升序）。
  final List<TimelineSample> samples;

  /// 是否没有采样。
  bool get isEmpty => samples.isEmpty;

  /// 从 JSON 读取；版本/字段不合法时抛 [FormatException]。
  factory RecordingTimeline.fromJson(Map<String, Object?> json) {
    final version = (json['version'] as num?)?.toInt() ?? formatVersion;
    if (version < minSupportedVersion || version > formatVersion) {
      throw FormatException('不支持的时间轴版本：$version');
    }
    final scriptId = json['scriptId'];
    if (scriptId is! String || scriptId.isEmpty) {
      throw const FormatException('时间轴缺少 scriptId');
    }
    final rawSamples = json['samples'];
    final samples = <TimelineSample>[];
    if (rawSamples is List) {
      for (final raw in rawSamples) {
        if (raw is Map) {
          samples.add(
            TimelineSample.fromJson(raw.cast<String, Object?>()),
          );
        }
      }
    }
    final duration = (json['durationMs'] as num?)?.toInt() ??
        (samples.isEmpty ? 0 : samples.last.t);
    return RecordingTimeline(
      version: version,
      scriptId: scriptId,
      durationMs: duration < 0 ? 0 : duration,
      samples: List.unmodifiable(samples),
    );
  }

  /// 解析 JSON 文本；失败返回 null（坏数据不阻断复盘入口）。
  static RecordingTimeline? tryDecode(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      return RecordingTimeline.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  /// 序列化为 JSON。
  Map<String, Object?> toJson() => {
        'version': version,
        'scriptId': scriptId,
        'durationMs': durationMs,
        'samples': samples.map((sample) => sample.toJson()).toList(),
      };

  /// 序列化为 JSON 文本。
  String encode() => jsonEncode(toJson());

  /// 回放时的线性插值（§9.3：按行号插值，越界夹到首/尾采样）。
  int anchorAt(int ms) => positionAt(ms).line;

  /// 回放位置：行号 + 行内字符偏移。
  ///
  /// 行号仍按线性插值；字符偏移只在同一行的两个采样之间插值，
  /// 跨行时使用对应端点的偏移，避免把上一段的字符位置带到下一段。
  ({int line, int char}) positionAt(int ms) {
    if (samples.isEmpty) return (line: 0, char: 0);
    if (ms <= samples.first.t) {
      return (line: samples.first.anchor, char: samples.first.char);
    }
    if (ms >= samples.last.t) {
      return (line: samples.last.anchor, char: samples.last.char);
    }

    var low = 0;
    var high = samples.length - 1;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (samples[mid].t <= ms) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final start = samples[low];
    final end = samples[high];
    if (end.t == start.t) return (line: end.anchor, char: end.char);
    final ratio = (ms - start.t) / (end.t - start.t);
    final value = start.anchor + (end.anchor - start.anchor) * ratio;
    final line = value.round();
    if (start.anchor == end.anchor) {
      final offset = start.char + (end.char - start.char) * ratio;
      return (line: line, char: offset.round());
    }
    if (line == start.anchor) return (line: line, char: start.char);
    if (line == end.anchor) return (line: line, char: end.char);
    return (line: line, char: 0);
  }
}

/// 10 Hz 时间轴采样器：由录制控制器按固定节拍喂入当前锚点。
class TimelineBuilder {
  /// 创建采样器。
  TimelineBuilder({
    required this.scriptId,
    this.intervalMs = 100,
  });

  /// 所属台本 id。
  final String scriptId;

  /// 采样间隔（毫秒）。
  final int intervalMs;

  final List<TimelineSample> _samples = <TimelineSample>[];

  /// 已采样的序列（只读）。
  List<TimelineSample> get samples => List.unmodifiable(_samples);

  /// 采样；过密（小于采样间隔）的调用被丢弃。
  void sample(int tMs, int anchor, {int char = 0, double conf = 0}) {
    final t = tMs < 0 ? 0 : tMs;
    final line = anchor < 0 ? 0 : anchor;
    final offset = char < 0 ? 0 : char;
    if (_samples.isNotEmpty && t - _samples.last.t < intervalMs) return;
    _samples.add(
      TimelineSample(t: t, anchor: line, char: offset, conf: conf),
    );
  }

  /// 结束采样并生成时间轴；总时长不早于最后采样时间。
  RecordingTimeline finish(int durationMs) {
    final last = _samples.isEmpty ? 0 : _samples.last.t;
    final duration = durationMs < last ? last : durationMs;
    return RecordingTimeline(
      scriptId: scriptId,
      durationMs: duration,
      samples: List.unmodifiable(_samples),
    );
  }
}
