import 'dart:async';

import 'package:flutter/services.dart';

/// 主阅读页与悬浮窗引擎之间的消息协议常量。
abstract final class OverlayChannel {
  static const String typeReady = 'ready';
  static const String typeInit = 'init';
  static const String typeAnchor = 'anchor';
  static const String typePosition = 'position';
  static const String typeClose = 'close';
  static const String typeState = 'state';
  static const String typeStyle = 'style';
  static const String typeControl = 'control';

  // 浮窗 → 主页面的控制动作。
  static const String actionTogglePause = 'toggle_pause';
  static const String actionPrevLine = 'prev_line';
  static const String actionNextLine = 'next_line';
  static const String actionToggleMic = 'toggle_mic';
  static const String actionToggleLock = 'toggle_lock';
}

/// 通过本地 `overlay_bridge` 插件在两条 FlutterEngine 之间转发 JSON。
///
/// 悬浮窗引擎由 `flutter_overlay_window` 单独创建；插件自带的 messenger
/// 会在该引擎内回环，不能用于反向控制，因此使用独立的原生转发通道。
abstract final class OverlayBridge {
  static const BasicMessageChannel<dynamic> _channel =
      BasicMessageChannel<dynamic>(
    'com.tp.prompter.teleprompter/overlay_bridge',
    JSONMessageCodec(),
  );

  // 生命周期与整个应用一致，随进程退出释放。
  // ignore: close_sinks
  static final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  static var _listening = false;

  /// 当前引擎收到的消息。插件内部的单订阅限制由广播流隔离。
  static Stream<dynamic> get incoming {
    if (!_listening) {
      _listening = true;
      _channel.setMessageHandler((message) async {
        _incoming.add(message);
        return null;
      });
    }
    return _incoming.stream;
  }

  /// 发送到另一条引擎；对方未运行时原生侧丢弃。
  static Future<void> send(Map<String, Object?> payload) async {
    try {
      await _channel.send(payload);
    } catch (_) {
      // 另一条引擎已销毁时忽略。
    }
  }
}
