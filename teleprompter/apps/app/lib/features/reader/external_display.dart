import 'dart:async';

import 'package:flutter/services.dart';

/// 外接显示器（E7-1）：Android `DisplayManager` 枚举到的副屏。
class ExternalDisplay {
  const ExternalDisplay({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.presentation = true,
  });

  final int id;
  final String name;
  final int width;
  final int height;

  /// 是否支持 `Presentation`（HDMI/DP/虚拟显示通常为 true）。
  final bool presentation;

  static ExternalDisplay? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    if (id is! int) return null;
    final name = value['name'];
    final width = value['width'];
    final height = value['height'];
    final presentation = value['presentation'];
    return ExternalDisplay(
      id: id,
      name: name is String && name.isNotEmpty ? name : 'Display $id',
      width: width is int ? width : 0,
      height: height is int ? height : 0,
      presentation: presentation is bool ? presentation : true,
    );
  }
}

/// 外接显示桥：枚举副屏、显示/更新/关闭纯稿件窗口。
///
/// 非 Android 或原生未实现时静默降级为空列表，不影响应用内提词。
class ExternalDisplayService {
  ExternalDisplayService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('tps/display') {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<int> _removed = StreamController<int>.broadcast();

  /// 副屏被拔出/断开时发出其 displayId。
  Stream<int> get removedDisplays => _removed.stream;

  Future<List<ExternalDisplay>> listDisplays() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listDisplays');
      if (raw == null) return const [];
      return raw
          .map(ExternalDisplay.tryParse)
          .whereType<ExternalDisplay>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 在指定副屏显示纯稿件；失败返回 false。
  ///
  /// [bandRatio] 为当前行在副屏上的纵向位置（0–1，默认居中），
  /// 与主阅读带的比例保持一致。
  Future<bool> show({
    required int displayId,
    required List<String> lines,
    required int anchor,
    required double fontSize,
    required bool mirrored,
    double bandRatio = 0.5,
  }) async {
    try {
      await _channel.invokeMethod<void>('present', {
        'displayId': displayId,
        'lines': lines,
        'anchor': anchor,
        'fontSize': fontSize,
        'mirrored': mirrored,
        'bandRatio': bandRatio,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 滚动或样式变化时刷新副屏内容；失败静默（副屏可能已被拔掉）。
  Future<void> update({
    required List<String> lines,
    required int anchor,
    required double fontSize,
    required bool mirrored,
    double bandRatio = 0.5,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'lines': lines,
        'anchor': anchor,
        'fontSize': fontSize,
        'mirrored': mirrored,
        'bandRatio': bandRatio,
      });
    } catch (_) {
      // 副屏断开或原生未实现时忽略。
    }
  }

  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('dismiss');
    } catch (_) {
      // 已关闭或未实现时忽略。
    }
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'displayRemoved') return;
    final id = call.arguments;
    if (id is int) _removed.add(id);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_removed.close());
  }
}
