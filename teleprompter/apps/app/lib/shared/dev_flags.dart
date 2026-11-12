import 'package:flutter/foundation.dart';

/// 开发测试入口开关。
///
/// release 包默认关闭；调试构建或显式
/// `--dart-define=TP_DEV_AUDIO=true` 构建时开启。
const bool devAudioEnabled = kDebugMode || bool.fromEnvironment('TP_DEV_AUDIO');
