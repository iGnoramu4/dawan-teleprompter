import 'package:flutter/material.dart';

/// 阅读画布独立调色板（§19.2）：不跟随壁纸动态取色，保证舞台对比度。
class StagePalette {
  const StagePalette({
    required this.background,
    required this.text,
    required this.dimText,
    required this.highlightBackground,
    required this.highlightBar,
    required this.controlSurface,
    required this.onControlSurface,
  });

  final Color background;
  final Color text;
  final Color dimText;
  final Color highlightBackground;

  /// 当前行左侧标记条：高亮不只用颜色背景，满足"颜色非唯一载体"。
  final Color highlightBar;

  final Color controlSurface;
  final Color onControlSurface;

  /// 舞台暗：纯黑底 + 近白字（对比度约 18:1）。
  static const StagePalette stageDark = StagePalette(
    background: Color(0xFF000000),
    text: Color(0xFFF2F2F2),
    dimText: Color(0xFFA0A0A0),
    highlightBackground: Color(0xFF1C1C1C),
    highlightBar: Color(0xFFFFC400),
    controlSurface: Color(0xFF171717),
    onControlSurface: Color(0xFFEDEDED),
  );

  /// 高对比白：明亮环境。
  static const StagePalette stageWhite = StagePalette(
    background: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    dimText: Color(0xFF555555),
    highlightBackground: Color(0xFFF0F0F0),
    highlightBar: Color(0xFF9A6B00),
    controlSurface: Color(0xFFF5F5F5),
    onControlSurface: Color(0xFF1A1A1A),
  );
}
