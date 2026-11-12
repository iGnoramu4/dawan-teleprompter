import 'dart:math' as math;

/// 固定阅读带（屏幕空间的静态矩形）。
///
/// 视觉行通过 `position` 移动到带内；带本身不随行号移动。
class ReadingBand {
  /// 创建阅读带。
  ///
  /// [safeTop] / [safeBottom] 为屏幕安全区（px）；
  /// [bandRatio] 为带中心在安全区高度中的比例；
  /// [rowHeight] / [rowGap] 来自 [LayoutSnapshot]。
  ReadingBand({
    required this.viewportHeight,
    required double safeTop,
    required double safeBottom,
    required this.bandRatio,
    required this.rowHeight,
    required this.rowGap,
    this.minRowsAbove = 1,
    this.minRowsBelow = 2,
    this.prismDy = 0,
  })  : _safeTop = safeTop,
        _safeBottom = math.max(safeTop + rowHeight, safeBottom);

  /// 视口高度。
  final double viewportHeight;

  /// 安全区顶部。
  final double _safeTop;

  /// 安全区底部。
  final double _safeBottom;

  /// 带中心比例（0–1）。
  final double bandRatio;

  /// 视觉行高度。
  final double rowHeight;

  /// 视觉行间距。
  final double rowGap;

  /// 带上方至少保留的完整行数。
  final int minRowsAbove;

  /// 带下方至少保留的完整行数。
  final int minRowsBelow;

  /// 垂直分光镜校准比例（±0.05 屏高）。
  final double prismDy;

  /// 安全区顶部。
  double get safeTop => _safeTop;

  /// 安全区底部。
  double get safeBottom => _safeBottom;

  /// 视觉行行距。
  double get pitch => rowHeight + rowGap;

  /// 带中心（px，已按安全区与最小上下行数夹取）。
  double get bandCenter {
    final usable = math.max(0.0, _safeBottom - _safeTop);
    final raw = _safeTop + usable * bandRatio;
    final minCenter = _safeTop + rowHeight / 2;
    final maxCenter = _safeBottom - rowHeight / 2;
    if (maxCenter <= minCenter) return minCenter;
    final above = minRowsAbove * pitch + rowHeight / 2;
    final below = minRowsBelow * pitch + rowHeight / 2;
    final lo = _safeTop + above;
    final hi = _safeBottom - below;
    if (lo <= hi) return raw.clamp(lo, hi).toDouble();
    return raw.clamp(minCenter, maxCenter).toDouble();
  }

  /// 带顶（px）。
  double get bandTop => bandCenter - rowHeight / 2;

  /// 安全区内可完整显示的行数（至少 1）。
  int get rowsVisible =>
      math.max(1, ((_safeBottom - _safeTop + rowGap) / pitch).floor());

  /// 带上方行数。
  int get rowsAbove {
    final value = ((bandTop - _safeTop + rowGap) / pitch).floor();
    return math.max(0, value);
  }

  /// 带下方行数。
  int get rowsBelow => math.max(0, rowsVisible - rowsAbove - 1);

  /// 某视觉行走进阅读带所需的内容滚动偏移（未镜像）。
  double targetForRow(int row) => row * pitch;

  /// 连续行位置走进阅读带所需的偏移（未镜像），支持分数行。
  double targetForRowPosition(double rowPosition) => rowPosition * pitch;

  /// 某视觉行走进阅读带所需的内容滚动偏移（含垂直镜像与分光镜）。
  ///
  /// 推导：渲染映射 `y = contentY - position`，镜像后
  /// `y2 = H - y1`，再加上 `prismDy × H`；令 `y2 + prism = bandTop`。
  double targetForRowWithMirror(int row, {required bool mirrorY}) =>
      targetForRowPositionWithMirror(row.toDouble(), mirrorY: mirrorY);

  /// 连续行位置对应的滚动偏移（含垂直镜像与分光镜）。
  double targetForRowPositionWithMirror(
    double rowPosition, {
    required bool mirrorY,
  }) {
    if (!mirrorY) return targetForRowPosition(rowPosition);
    return rowPosition * pitch +
        2 * bandTop -
        viewportHeight -
        prismDy * viewportHeight;
  }

  /// 某视觉行在屏幕上的行顶（用于位置强调/调试）。
  double screenTopForRow(
    int row,
    double position, {
    required bool mirrorY,
  }) {
    final contentTop = bandTop + row * pitch;
    final y1 = contentTop - position;
    final y2 = mirrorY ? viewportHeight - y1 : y1;
    return y2 + prismDy * viewportHeight;
  }

  /// 该位置对应阅读带中心附近的视觉行。
  int rowAtPosition(double position) {
    if (pitch <= 0) return 0;
    return (position / pitch).round();
  }
}

/// 位置强调：按「行中心离带中心的距离」连续衰减，而不是按行号身份。
abstract final class BandEmphasis {
  /// 默认衰减半径（单位：行）。
  static const double defaultRadius = 0.9;

  /// 按行号差计算强调度（0–1）。
  ///
  /// 带内行 = 1，相邻行按 [radius] 线性衰减到 0。
  static double valueForRow({
    required int row,
    required int anchorRow,
    double radius = defaultRadius,
  }) {
    if (radius <= 0) return row == anchorRow ? 1.0 : 0.0;
    final distance = (row - anchorRow).abs() / radius;
    return (1.0 - distance).clamp(0.0, 1.0).toDouble();
  }

  /// 按屏幕几何计算强调度（0–1），用于连续跟随场景。
  static double valueForScreen({
    required double screenRowTop,
    required double rowHeight,
    required double bandCenter,
    required double pitch,
    double radius = defaultRadius,
  }) {
    if (pitch <= 0 || radius <= 0) return 0;
    final center = screenRowTop + rowHeight / 2;
    final distance = (center - bandCenter).abs() / pitch / radius;
    return (1.0 - distance).clamp(0.0, 1.0).toDouble();
  }
}
