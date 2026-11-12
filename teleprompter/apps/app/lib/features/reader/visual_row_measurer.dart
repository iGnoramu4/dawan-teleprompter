import 'dart:math' as math;

import 'package:core_reader_layout/core_reader_layout.dart';
import 'package:flutter/widgets.dart';

/// 用 `TextPainter` 复刻真实渲染的视觉行测量。
///
/// 整篇连续文本可能包含换行（`\n` 或 `\r\n`）。这些换行必须被当作
/// **视觉行的分隔**，而不是留在行文本里：带前导换行的行文字会在单行高度
/// 的容器里先渲染一个空行，真实内容被挤到容器外而不可见（P1 缺陷）。
class FlutterRowMeasurer implements RowMeasurer {
  /// 创建测量器。
  FlutterRowMeasurer({
    required this.style,
    required this.textScaler,
    required this.align,
  });

  /// 正文样式，必须与渲染时一致。
  final TextStyle style;

  /// 系统字体缩放。
  final TextScaler textScaler;

  /// 对齐方式。
  final TextAlign align;

  @override
  List<MeasuredRow> measure(String text, {required double maxWidth}) {
    final width = math.max(1.0, maxWidth);
    final rows = <MeasuredRow>[];
    for (final segment in _hardLineSegments(text)) {
      _measureSegment(
        text.substring(segment.start, segment.end),
        base: segment.start,
        maxWidth: width,
        out: rows,
      );
    }
    return rows;
  }

  /// 按硬换行切段，返回每段在原文中的 [start, end)。
  ///
  /// 段内（不含换行）不会出现 `\n` / `\r`；空段也要保留，渲染为一条空视觉行。
  List<({int start, int end})> _hardLineSegments(String text) {
    final segments = <({int start, int end})>[];
    var start = 0;
    var i = 0;
    while (i < text.length) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x0A || unit == 0x0D) {
        segments.add((start: start, end: i));
        if (unit == 0x0D &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
        start = i + 1;
      }
      i++;
    }
    segments.add((start: start, end: text.length));
    return segments;
  }

  void _measureSegment(
    String segment, {
    required int base,
    required double maxWidth,
    required List<MeasuredRow> out,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: segment, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    final metrics = painter.computeLineMetrics();
    if (segment.isEmpty || metrics.isEmpty) {
      out.add(
        MeasuredRow(
          charStart: base,
          charEnd: base + segment.length,
          text: segment,
          height: math.max(1, painter.height),
        ),
      );
      return;
    }

    var start = 0;
    for (var i = 0; i < metrics.length && start < segment.length; i++) {
      final boundary = painter.getLineBoundary(TextPosition(offset: start));
      var end = boundary.end.clamp(start, segment.length);
      if (end == start) {
        // 边界不再推进：把剩余文本整体作为一行兜底，绝不吞字。
        end = segment.length;
      }
      out.add(
        MeasuredRow(
          charStart: base + start,
          charEnd: base + end,
          text: segment.substring(start, end),
          height: math.max(1, metrics[i].height),
        ),
      );
      start = end;
    }
    if (start < segment.length) {
      // 行度量数与实际内容不一致时兜底，保证每个字符都落在某一行里。
      out.add(
        MeasuredRow(
          charStart: base + start,
          charEnd: base + segment.length,
          text: segment.substring(start),
          height: math.max(1, metrics.last.height),
        ),
      );
    }
  }
}
