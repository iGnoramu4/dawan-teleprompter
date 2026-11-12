import 'package:data_store/data_store.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../shared/reader_settings/overlay_settings.dart';

/// 悬浮窗参数的持久化键（不与台本预设混用）。
const String overlaySettingsKey = 'overlay:global';

/// `flutter_overlay_window` 的薄封装：权限、显示/关闭、位置读取与参数持久化。
///
/// 只暴露最小的能力面，便于后续替换平台实现（DEPENDENCY_POLICY §2.7）。
class OverlayWindowService {
  OverlayWindowService(this._repository);

  final ScriptRepository _repository;

  Future<bool> isPermissionGranted() =>
      FlutterOverlayWindow.isPermissionGranted();

  /// 跳系统设置页；返回后再次查询，兼容部分 ROM 不返回 result 的情况。
  Future<bool> requestPermission() async {
    final result = await FlutterOverlayWindow.requestPermission();
    if (result == true) return true;
    return FlutterOverlayWindow.isPermissionGranted();
  }

  Future<bool> isActive() => FlutterOverlayWindow.isActive();

  Future<OverlaySettings> loadSettings() async {
    final json = await _repository.loadPreset(overlaySettingsKey);
    if (json == null) return OverlaySettings.defaults;
    try {
      return OverlaySettings.fromJson(json);
    } catch (_) {
      return OverlaySettings.defaults;
    }
  }

  Future<void> saveSettings(OverlaySettings settings) =>
      _repository.savePreset(overlaySettingsKey, settings.toJson());

  Future<void> show({
    required OverlaySettings settings,
    required String title,
    required double devicePixelRatio,
  }) {
    final x = settings.x;
    final y = settings.y;
    // 初始窗口尺寸与位置在插件里按物理像素生效（resize/move 才走 dp），
    // 这里统一从 dp 换算，避免不同密度机型上窗口偏小或偏移。
    final widthPx = (settings.widthDp * devicePixelRatio).round();
    final heightPx = (settings.heightDp * devicePixelRatio).round();
    return FlutterOverlayWindow.showOverlay(
      width: widthPx,
      height: heightPx,
      alignment: OverlayAlignment.topCenter,
      enableDrag: true,
      overlayTitle: title,
      overlayContent: title,
      startPosition: x != null && y != null
          ? OverlayPosition(x * devicePixelRatio, y * devicePixelRatio)
          : null,
    );
  }

  Future<void> close() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<OverlayPosition?> currentPosition() async {
    try {
      return await FlutterOverlayWindow.getOverlayPosition();
    } catch (_) {
      return null;
    }
  }
}
