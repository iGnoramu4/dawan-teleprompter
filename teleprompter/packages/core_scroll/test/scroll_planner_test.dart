import 'package:core_scroll/core_scroll.dart';
import 'package:test/test.dart';

void main() {
  test('小于半行的目标变化被忽略', () {
    final planner = ScrollPlanner();
    planner.setTarget(30, lineHeight: 100);
    expect(planner.target, 0);
  });

  test('目标更新后弹簧收敛且不过冲', () {
    final planner = ScrollPlanner();
    planner.setTarget(300, lineHeight: 100, immediate: true);
    double maxPosition = 0;
    for (var i = 0; i < 120; i++) {
      planner.step(1 / 60);
      maxPosition =
          maxPosition < planner.position ? planner.position : maxPosition;
    }
    expect(planner.position, closeTo(300, 1.0));
    expect(maxPosition, lessThanOrEqualTo(300.5));
  });

  test('冻结后停在当前位置', () {
    final planner = ScrollPlanner();
    planner.setTarget(500, lineHeight: 100, immediate: true);
    planner.step(1 / 60);
    planner.freeze();
    final frozenAt = planner.position;
    for (var i = 0; i < 60; i++) {
      planner.step(1 / 60);
    }
    expect(planner.position, closeTo(frozenAt, 0.01));
    expect(planner.frozen, isTrue);
  });

  test('手动滚动按行/秒推进并受边界限制', () {
    final planner = ScrollPlanner()
      ..configureBounds(min: 0, max: 600)
      ..setLineHeight(100)
      ..jumpTo(0);
    planner
      ..position = 0
      ..advanceManual(1.0, linesPerSecond: 2);
    expect(planner.position, closeTo(200, 1e-6));
    planner.advanceManual(10, linesPerSecond: 2);
    expect(planner.position, 600);
  });
}
