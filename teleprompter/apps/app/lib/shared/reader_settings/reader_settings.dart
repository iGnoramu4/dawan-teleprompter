import 'dart:convert';
import 'dart:math' as math;

import 'package:asr_kit/asr_kit.dart';
import 'package:core_alignment/core_alignment.dart';

/// 阅读画布配色（§19.5：舞台暗 / 高对比白，切换不改变进度）。
enum ReaderTheme { stageDark, stageWhite }

/// 读到篇尾后的行为（C-09 / 2026-11-09 决策）。
enum ReaderEndBehavior { stop, loop }

/// 语音跟随使用的识别模型（默认中文轻量 14M，中英混合可手动切换）。
enum AsrModelChoice { bilingualMixed, zh14m }

/// 选择项到随包模型规格的映射。
extension AsrModelChoiceSpec on AsrModelChoice {
  /// 对应的模型文件清单。
  AsrModelSpec get spec => switch (this) {
        AsrModelChoice.bilingualMixed => AsrModelSpec.zipformerBilingualMixed,
        AsrModelChoice.zh14m => AsrModelSpec.zh14mInt8,
      };
}

/// 阅读排版与滚动参数（§4.3 C-02/C-06/C-09、§4.4 L-01~L-09）。
///
/// 这些参数按台本持久化到 `presets` 表（key = `script:<scriptId>`），
/// 切稿时自动加载（C-06）。
class ReaderSettings {
  const ReaderSettings({
    this.theme = ReaderTheme.stageDark,
    this.fontSize = 44,
    this.lineHeight = 1.55,
    this.fontWeight = 900,
    this.letterSpacing = 0.8,
    this.leftMargin = 0.06,
    this.rightMargin = 0.06,
    this.matchTolerance = MatchTolerance.standard,
    this.alignCenter = false,
    this.mirrorX = false,
    this.mirrorY = false,
    this.prismDx = 0,
    this.prismDy = 0,
    this.speed = 1.2,
    this.readAheadRatio = 0.34,
    this.smoothness = 8.0,
    this.pauseStop = true,
    this.keepScreenOn = true,
    this.lineStepFollow = true,
    this.latencyCompensation = true,
    this.asrModel = AsrModelChoice.zh14m,
    this.endBehavior = ReaderEndBehavior.stop,
  });

  /// 默认值（等价于 §19.5 的"舞台暗"基线）。
  static const ReaderSettings defaults = ReaderSettings();

  /// 当前排版模型版本。
  ///
  /// 1 = 旧版：`lineHeight` 是 TextStyle 的高度倍数，额外再叠加 `lineGapFor`；
  /// 2 = 新版：`lineHeight` 是包含行间距的总行距倍数（默认 1.55）。
  static const int currentTypographyModel = 2;

  /// 预设 JSON 中的排版模型标记键。
  static const String typographyModelKey = 'typographyModel';

  final ReaderTheme theme;

  /// 24–160 px（L-01）。
  final double fontSize;

  /// 1.0–2.5×（L-02）。
  final double lineHeight;

  /// 400–900（L-05）。默认 900 = 内置思源黑体 Heavy。
  final double fontWeight;

  /// -1–+3（L-05）。
  final double letterSpacing;

  /// 左边距占屏宽比例 0–0.4（L-03）。
  final double leftMargin;

  /// 右边距占屏宽比例 0–0.4（L-03）。
  final double rightMargin;

  /// 语音匹配档位（C-09）：五档，映射到闸门与对齐窗口参数。
  ///
  /// 档位是「全局上限」；连续朗读时由 `ContinuousSpeechMonitor` 在档位内
  /// 自适应放宽一档，退出后自动回到当前档位。
  final MatchTolerance matchTolerance;

  /// 左对齐 / 居中（L-06）。
  final bool alignCenter;

  /// 水平 / 垂直镜像（L-09）。
  final bool mirrorX;
  final bool mirrorY;

  /// 分光镜偏移校准，占屏宽/高比例，±0.05（L-09）。
  final double prismDx;
  final double prismDy;

  /// 0.2–10 行/秒（C-02）。
  final double speed;

  /// 语音跟随提前量（锚点位置）0.2–0.6（C-09）。
  final double readAheadRatio;

  /// 弹簧平滑度（omega 4–12，C-09）。
  final double smoothness;

  /// 停顿停住（C-09）。
  final bool pauseStop;

  /// 屏幕常亮（C-08）。
  final bool keepScreenOn;

  /// 逐行跟随（C-09）：识别命中下一行才切行；关闭后回到连续平滑跟随。
  final bool lineStepFollow;

  /// 端到端延迟补偿：把「采集分片 + 解码出文 + 一帧渲染」的延迟前馈到
  /// 滚动目标，让换行略早于语音。关闭后即为对照基线。
  final bool latencyCompensation;

  /// 语音识别模型（默认中文轻量 14M；中英混合作为可选回退项）。
  final AsrModelChoice asrModel;

  /// 篇尾行为：默认停止，可切换循环。
  final ReaderEndBehavior endBehavior;

  bool get mirrorAny => mirrorX || mirrorY;

  ReaderSettings copyWith({
    ReaderTheme? theme,
    double? fontSize,
    double? lineHeight,
    double? fontWeight,
    double? letterSpacing,
    double? leftMargin,
    double? rightMargin,
    MatchTolerance? matchTolerance,
    bool? alignCenter,
    bool? mirrorX,
    bool? mirrorY,
    double? prismDx,
    double? prismDy,
    double? speed,
    double? readAheadRatio,
    double? smoothness,
    bool? pauseStop,
    bool? keepScreenOn,
    bool? lineStepFollow,
    bool? latencyCompensation,
    AsrModelChoice? asrModel,
    ReaderEndBehavior? endBehavior,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontWeight: fontWeight ?? this.fontWeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      leftMargin: leftMargin ?? this.leftMargin,
      rightMargin: rightMargin ?? this.rightMargin,
      matchTolerance: matchTolerance ?? this.matchTolerance,
      alignCenter: alignCenter ?? this.alignCenter,
      mirrorX: mirrorX ?? this.mirrorX,
      mirrorY: mirrorY ?? this.mirrorY,
      prismDx: prismDx ?? this.prismDx,
      prismDy: prismDy ?? this.prismDy,
      speed: speed ?? this.speed,
      readAheadRatio: readAheadRatio ?? this.readAheadRatio,
      smoothness: smoothness ?? this.smoothness,
      pauseStop: pauseStop ?? this.pauseStop,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      lineStepFollow: lineStepFollow ?? this.lineStepFollow,
      latencyCompensation: latencyCompensation ?? this.latencyCompensation,
      asrModel: asrModel ?? this.asrModel,
      endBehavior: endBehavior ?? this.endBehavior,
    );
  }

  /// 参数归一化：磁盘/滑块都可能越界，统一在这里收口。
  ReaderSettings normalized() {
    return copyWith(
      fontSize: fontSize.clamp(24.0, 160.0).toDouble(),
      lineHeight: lineHeight.clamp(1.0, 2.5).toDouble(),
      fontWeight: fontWeight.clamp(400.0, 900.0).toDouble(),
      letterSpacing: letterSpacing.clamp(-1.0, 3.0).toDouble(),
      leftMargin: leftMargin.clamp(0.0, 0.4).toDouble(),
      rightMargin: rightMargin.clamp(0.0, 0.4).toDouble(),
      prismDx: prismDx.clamp(-0.05, 0.05).toDouble(),
      prismDy: prismDy.clamp(-0.05, 0.05).toDouble(),
      speed: speed.clamp(0.2, 10.0).toDouble(),
      readAheadRatio: readAheadRatio.clamp(0.2, 0.6).toDouble(),
      smoothness: smoothness.clamp(4.0, 12.0).toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
        'theme': theme.name,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'fontWeight': fontWeight,
        'letterSpacing': letterSpacing,
        'leftMargin': leftMargin,
        'rightMargin': rightMargin,
        'matchTolerance': matchTolerance.name,
        'alignCenter': alignCenter,
        'mirrorX': mirrorX,
        'mirrorY': mirrorY,
        'prismDx': prismDx,
        'prismDy': prismDy,
        'speed': speed,
        'readAheadRatio': readAheadRatio,
        'smoothness': smoothness,
        'pauseStop': pauseStop,
        'keepScreenOn': keepScreenOn,
        'lineStepFollow': lineStepFollow,
        'latencyCompensation': latencyCompensation,
        'asrModel': asrModel.name,
        'endBehavior': endBehavior.name,
        typographyModelKey: currentTypographyModel,
      };

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final themeName = json['theme'];
    final theme = ReaderTheme.values.firstWhere(
      (item) => item.name == themeName,
      orElse: () => ReaderTheme.stageDark,
    );

    final modelValue = json[typographyModelKey];
    final typographyModel =
        modelValue is num ? modelValue.toInt() : 1; // 缺少标记 = 旧预设，必须保持原观感。
    final rawLineHeight = readDouble(
      'lineHeight',
      typographyModel >= currentTypographyModel ? 1.55 : 1.5,
    );
    final lineHeight = typographyModel >= currentTypographyModel
        ? rawLineHeight
        : legacyLineHeightToPitch(rawLineHeight);

    final behaviorName = json['endBehavior'];
    final endBehavior = ReaderEndBehavior.values.firstWhere(
      (item) => item.name == behaviorName,
      orElse: () => ReaderEndBehavior.stop,
    );

    final asrModelName = json['asrModel'];
    // 缺失或未知取值直接回落到默认（中文轻量 14M）。
    final asrModel = AsrModelChoice.values.firstWhere(
      (item) => item.name == asrModelName,
      orElse: () => AsrModelChoice.zh14m,
    );

    return ReaderSettings(
      theme: theme,
      fontSize: readDouble('fontSize', 44),
      lineHeight: lineHeight,
      fontWeight: readDouble('fontWeight', 900),
      letterSpacing: readDouble('letterSpacing', 0.8),
      leftMargin: readDouble('leftMargin', 0.06),
      rightMargin: readDouble('rightMargin', 0.06),
      matchTolerance: MatchProfile.parse(json['matchTolerance']),
      alignCenter: readBool('alignCenter', false),
      mirrorX: readBool('mirrorX', false),
      mirrorY: readBool('mirrorY', false),
      prismDx: readDouble('prismDx', 0),
      prismDy: readDouble('prismDy', 0),
      speed: readDouble('speed', 1.2),
      readAheadRatio: readDouble('readAheadRatio', 0.34),
      smoothness: readDouble('smoothness', 8.0),
      pauseStop: readBool('pauseStop', true),
      keepScreenOn: readBool('keepScreenOn', true),
      lineStepFollow: readBool('lineStepFollow', true),
      latencyCompensation: readBool('latencyCompensation', true),
      asrModel: asrModel,
      endBehavior: endBehavior,
    ).normalized();
  }

  /// 旧排版模型（1）的 `lineHeight` 折算为新的「总行距倍数」。
  ///
  /// 旧实际行距 = `h`（TextStyle 高度）+ 上下内边距 0.28 + 行间距
  /// `max(0.12, h - 1) × 1.1`；折算后打开旧预设不会跳变。
  static double legacyLineHeightToPitch(double legacyLineHeight) {
    final h = legacyLineHeight.isFinite ? legacyLineHeight : 1.5;
    return h + 0.28 + math.max(0.12, h - 1.0) * 1.1;
  }

  /// TextStyle 的高度倍数（新版 `lineHeight` 去掉内边距与行间距后的部分）。
  double get textStyleHeight => (lineHeight - 0.20).clamp(1.0, 3.8).toDouble();

  /// 视觉行间距（px）：新版固定为字号的 0.10。
  double rowGapFor(double size) => size * 0.10;

  /// 视觉行上下内边距（单侧，px）：新版固定为字号的 0.05。
  double rowPadYFor(double size) => size * 0.05;

  /// 当前字号下每行的间距（px），随字号与行距线性变化。
  double lineGapFor(double size) =>
      size * math.max(0.12, lineHeight - 1.0) * 1.1;

  /// 稿件画布宽度（px）：屏宽减去左右实际边距，最大 980。
  ///
  /// 渲染与测量都必须用这个值，避免"测量按边距、渲染按全屏"导致
  /// 边距失效与行高错位。
  double stageWidthFor(double viewportWidth) {
    final available = viewportWidth * (1 - leftMargin - rightMargin);
    return math.min(math.max(0.0, available), 980.0).toDouble();
  }

  /// 画布左缘偏移（px）：左边缘距 + 宽度封顶后剩余空间的居中量。
  ///
  /// 左右边距不等时画布不能整体居中，否则两侧实际留白与设置不符。
  double stageLeftFor(double viewportWidth) {
    final available = viewportWidth * (1 - leftMargin - rightMargin);
    if (available <= 0) return 0;
    final width = stageWidthFor(viewportWidth);
    return viewportWidth * leftMargin + (available - width) / 2;
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析 [toJsonString] 写出的内容；非法内容抛 [FormatException]。
  static ReaderSettings fromRaw(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return ReaderSettings.fromJson(decoded);
    }
    throw const FormatException('reader settings is not a JSON object');
  }

  @override
  String toString() =>
      'ReaderSettings(theme: ${theme.name}, fontSize: $fontSize, '
      'lineHeight: $lineHeight, matchTolerance: ${matchTolerance.name}, '
      'mirrorX: $mirrorX, mirrorY: $mirrorY, speed: $speed)';
}
