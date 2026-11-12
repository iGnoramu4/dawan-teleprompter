/// 阅读页布局模型：视觉行、固定阅读带、一阶限速跟随与位置强调。
///
/// 该包保持纯 Dart，不依赖 Flutter：文本测量由宿主通过 [RowMeasurer]
/// 注入（Flutter 侧用 `TextPainter` 实现，测试用 fake 实现）。
library;

export 'src/layout_snapshot.dart';
export 'src/reading_band.dart';
export 'src/reading_follower.dart';
