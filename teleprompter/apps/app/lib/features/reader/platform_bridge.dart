import 'package:flutter/services.dart';

/// Android 平台能力桥：通知权限与麦克风前台服务。
///
/// 悬浮窗由插件的 `specialUse` 前台服务持有；语音跟随时另起 `microphone`
/// 前台服务，保证退到其他应用后仍可收音（Android 14+ 的 FGS 类型约束）。
/// 桌面端没有对应实现，统一走静默降级。
abstract final class PlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.tp.prompter.teleprompter/platform',
  );

  /// Android 13+ 的通知权限；低版本或非 Android 返回 true。
  static Future<bool> notificationGranted() async {
    try {
      return await _channel.invokeMethod<bool>('notificationStatus') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 请求通知权限；被拒绝不阻断悬浮窗或语音跟随。
  static Future<bool> requestNotification() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotification') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 启动 `microphone` 类型前台服务（需 RECORD_AUDIO 已授权）。
  static Future<void> startVoiceService() async {
    try {
      await _channel.invokeMethod<void>('startVoiceService');
    } catch (_) {
      // 不支持或启动失败时沿用应用内收音。
    }
  }

  static Future<void> stopVoiceService() async {
    try {
      await _channel.invokeMethod<void>('stopVoiceService');
    } catch (_) {
      // 服务未运行时忽略。
    }
  }
}
