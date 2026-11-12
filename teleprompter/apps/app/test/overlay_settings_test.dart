import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/reader_settings/overlay_settings.dart';

void main() {
  test('默认悬浮窗参数与高度映射', () {
    const settings = OverlaySettings.defaults;
    expect(settings.widthDp, 360);
    expect(settings.opacity, closeTo(0.92, 1e-9));
    expect(settings.lineCount, 3);
    expect(settings.heightDp, 300);
    expect(settings.x, isNull);
    expect(settings.y, isNull);

    expect(settings.copyWith(lineCount: 5).heightDp, 420);
    expect(settings.copyWith(lineCount: 0).normalized().lineCount, 5);
    expect(settings.copyWith(lineCount: 0).normalized().heightDp, 420);
  });

  test('越界参数归一化', () {
    const settings = OverlaySettings(
      widthDp: 100,
      opacity: 1.5,
      lineCount: 7,
      fontSize: 8,
    );
    final normalized = settings.normalized();
    expect(normalized.widthDp, 200);
    expect(normalized.widthDp, lessThanOrEqualTo(1200));
    expect(normalized.opacity, 1.0);
    expect(normalized.lineCount, 5);
    expect(normalized.fontSize, 16);

    const wide = OverlaySettings(widthDp: 2400, opacity: 0.1);
    final wideNormalized = wide.normalized();
    expect(wideNormalized.widthDp, 1200);
    expect(wideNormalized.opacity, 0.3);
  });

  test('JSON 往返保留宽度、行数、字号与位置', () {
    const settings = OverlaySettings(
      widthDp: 420,
      opacity: 0.8,
      lineCount: 5,
      fontSize: 28,
      x: 12,
      y: 340,
    );
    final restored = OverlaySettings.fromJson(settings.toJson());
    expect(restored.widthDp, 420);
    expect(restored.opacity, closeTo(0.8, 1e-9));
    expect(restored.lineCount, 5);
    expect(restored.fontSize, 28);
    expect(restored.x, 12);
    expect(restored.y, 340);
  });

  test('缺少字段按默认值补齐', () {
    final restored = OverlaySettings.fromJson(const {});
    expect(restored.widthDp, OverlaySettings.defaults.widthDp);
    expect(restored.lineCount, 3);
    expect(restored.x, isNull);
    expect(restored.y, isNull);
  });

  test('旧「全稿」配置迁移为 5 行窗口', () {
    final restored = OverlaySettings.fromJson(const {'lineCount': 0});
    expect(restored.lineCount, 5);
    expect(restored.heightDp, 420);
  });
}
