import 'recording_timeline.dart';

/// 把时间轴转换为 SRT（E8-3）。按"停留行"切分：同一行连续的采样合并为一条字幕。
///
/// 台本行是排版后的行（近似句子），因此导出结果按行吸附，而不是按标点重切。
class TimelineSrtExporter {
  /// 创建导出器。
  const TimelineSrtExporter();

  /// 生成 SRT 文本；空台本/空时间轴返回空字符串。
  String build({
    required List<String> lines,
    required RecordingTimeline timeline,
  }) {
    if (lines.isEmpty || timeline.samples.isEmpty) return '';

    final buffer = StringBuffer();
    var index = 0;
    var segmentLine = timeline.samples.first.anchor;
    var segmentStart = timeline.samples.first.t;

    void closeSegment(int endMs) {
      if (endMs <= segmentStart) return;
      if (segmentLine < 0 || segmentLine >= lines.length) return;
      final text = _clean(lines[segmentLine]);
      if (text.isEmpty) return;
      index += 1;
      buffer
        ..writeln(index)
        ..writeln('${_timestamp(segmentStart)} --> ${_timestamp(endMs)}')
        ..writeln(text)
        ..writeln();
    }

    for (final sample in timeline.samples.skip(1)) {
      if (sample.anchor == segmentLine) continue;
      closeSegment(sample.t);
      segmentLine = sample.anchor;
      segmentStart = sample.t;
    }
    closeSegment(timeline.durationMs);
    return buffer.toString();
  }

  static String _clean(String line) =>
      line.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _timestamp(int ms) {
    final total = ms < 0 ? 0 : ms;
    final hours = total ~/ 3600000;
    final minutes = (total ~/ 60000) % 60;
    final seconds = (total ~/ 1000) % 60;
    final millis = total % 1000;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)},'
        '${millis.toString().padLeft(3, '0')}';
  }
}
