/// 悬浮提词窗口参数（W-02/W-03）：宽度、不透明度、可见行数与位置记忆。
///
/// 独立于阅读页排版参数，改动不影响主阅读画布。
class OverlaySettings {
  const OverlaySettings({
    this.widthDp = 360,
    this.opacity = 0.92,
    this.lineCount = 3,
    this.fontSize = 24,
    this.x,
    this.y,
  });

  static const OverlaySettings defaults = OverlaySettings();

  /// 窗口宽度 200–1200 dp（W-03）。
  final int widthDp;

  /// 不透明度 0.3–1.0（W-03）。
  final double opacity;

  /// 可见行数：仅支持 3 / 5；旧版 `0`（全稿）读取时迁移为 5。
  final int lineCount;

  /// 悬浮窗独立字号，不影响主阅读页。
  final double fontSize;

  /// 上次位置（dp），首次为空时由插件按 alignment 放置。
  final double? x;
  final double? y;

  /// 插件按 dp 设置窗口高度；行数越多越高。
  int get heightDp {
    // 每行最多折成两行，窗口高度需覆盖「行数 × 1.3 倍字号」加标题栏与控制栏。
    return lineCount >= 5 ? 420 : 300;
  }

  OverlaySettings normalized() {
    // 全稿模式已下线：0（旧全稿）与 >=5 都归一到 5 行，其余归一到 3 行。
    final lines = lineCount >= 5 || lineCount <= 0 ? 5 : 3;
    return copyWith(
      widthDp: widthDp.clamp(200, 1200),
      opacity: opacity.clamp(0.3, 1.0),
      lineCount: lines,
      fontSize: fontSize.clamp(16.0, 40.0),
    );
  }

  OverlaySettings copyWith({
    int? widthDp,
    double? opacity,
    int? lineCount,
    double? fontSize,
    double? x,
    double? y,
  }) {
    return OverlaySettings(
      widthDp: widthDp ?? this.widthDp,
      opacity: opacity ?? this.opacity,
      lineCount: lineCount ?? this.lineCount,
      fontSize: fontSize ?? this.fontSize,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, Object?> toJson() => {
        'widthDp': widthDp,
        'opacity': opacity,
        'lineCount': lineCount,
        'fontSize': fontSize,
        'x': x,
        'y': y,
      };

  static OverlaySettings fromJson(Map<String, Object?> json) {
    final x = json['x'];
    final y = json['y'];
    return const OverlaySettings()
        .copyWith(
          widthDp: (json['widthDp'] as num?)?.toInt(),
          opacity: (json['opacity'] as num?)?.toDouble(),
          lineCount: (json['lineCount'] as num?)?.toInt(),
          fontSize: (json['fontSize'] as num?)?.toDouble(),
          x: x is num ? x.toDouble() : null,
          y: y is num ? y.toDouble() : null,
        )
        .normalized();
  }
}
