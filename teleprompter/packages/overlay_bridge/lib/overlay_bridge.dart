/// 主引擎与悬浮窗引擎之间的 JSON 消息桥（仅 Android）。
///
/// 插件本身不暴露 Dart API：两端直接使用 [BasicMessageChannel]，
/// 原生层负责把任一引擎的消息转发给另一条引擎。
library;

/// 两端共用的通道名。
const String overlayBridgeChannel =
    'com.tp.prompter.teleprompter/overlay_bridge';
