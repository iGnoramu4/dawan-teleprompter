import 'package:flutter/material.dart';

/// 设计令牌（§19.10）：页面引用令牌，不写字面量。
abstract final class TpTokens {
  static const Color seed = Color(0xFF4F5BD5);

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  /// 通用可点击控件最小命中区（§19.7）。
  static const double touchTarget = 48;

  /// 遥控页等远距操作场景。
  static const double touchTargetRemote = 56;

  static const Duration durationShort = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationLong = Duration(milliseconds: 500);

  /// 阅读页字体：Source Han Sans SC Heavy / Noto Sans SC Black（SIL OFL 1.1）。
  /// 仅在阅读画布使用，编辑页与设置页保持 Material 默认字体。
  static const String readerFontFamily = 'SourceHanSansSC';
  static const FontWeight readerFontWeight = FontWeight.w900;

  /// 阅读画布字号范围（§4.4 L-01）。
  static const double readerMinFontSize = 24;
  static const double readerMaxFontSize = 160;

  /// 阅读页控件字阶（§19.2）。
  static const double readerCaptionFontSize = 11;
  static const double readerSmallFontSize = 13;
  static const double readerBodyFontSize = 14;
  static const double readerTitleFontSize = 16;

  /// 高亮条与下一行半亮的视觉参数（§4.4 L-07）。
  static const double readerHighlightBarWidth = 6;
  static const double readerHighlightBarGap = 8;
  static const double readerHighlightBarRadius = 3;
  static const double readerNextLineOpacity = 0.72;
  static const double readerControlDividerOpacity = 0.08;
  static const double readerControlFillOpacity = 0.06;
  static const double readerStepperMinWidth = 64;

  /// 壳层最大内容宽度，避免桌面端超宽行。
  static const double shellMaxWidth = 1200;
}
