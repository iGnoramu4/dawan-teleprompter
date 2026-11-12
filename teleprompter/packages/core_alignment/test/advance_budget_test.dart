import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

/// 累计跳行预算：单步 3 行只夹单次，连续三次 3 行必须被拦成逐行。
void main() {
  test('同一窗口内连续 3 行跳不累积', () {
    final budget = AutoAdvanceBudget();
    expect(budget.limit(from: 0, to: 3, nowMs: 0), 3, reason: '第一跳放行');
    expect(budget.limit(from: 3, to: 6, nowMs: 2000), 4, reason: '预算用尽后只允许 +1');
    expect(budget.limit(from: 4, to: 7, nowMs: 4000), 5, reason: '仍不得跳行');
    expect(budget.limit(from: 5, to: 8, nowMs: 6000), 6);
  });

  test('窗口滚过后重新放行', () {
    final budget = AutoAdvanceBudget();
    expect(budget.limit(from: 0, to: 3, nowMs: 0), 3);
    expect(budget.limit(from: 3, to: 6, nowMs: 9000), 4);
    // 0ms 的跳行已在 10000ms 窗口外，重新获得完整预算。
    expect(budget.limit(from: 4, to: 7, nowMs: 10000), 7);
  });

  test('逐行推进不计入预算', () {
    final budget = AutoAdvanceBudget();
    for (var i = 0; i < 20; i++) {
      expect(budget.limit(from: i, to: i + 1, nowMs: i * 300), i + 1);
    }
    expect(budget.limit(from: 20, to: 23, nowMs: 6000), 23,
        reason: '逐行推进不该把跳行预算消耗掉');
  });

  test('单次超过 3 行也只走一行', () {
    final budget = AutoAdvanceBudget();
    expect(budget.limit(from: 2, to: 12, nowMs: 0), 3);
  });

  test('窗口内跳行总和不超过 3 行', () {
    final budget = AutoAdvanceBudget();
    var line = 0;
    var totalJump = 0;
    for (var t = 0; t <= 9000; t += 1000) {
      final target = budget.limit(from: line, to: line + 3, nowMs: t);
      final delta = target - line;
      if (delta > 1) totalJump += delta;
      line = target;
    }
    expect(totalJump, lessThanOrEqualTo(3));
  });

  test('reset 后重新获得预算', () {
    final budget = AutoAdvanceBudget();
    expect(budget.limit(from: 0, to: 3, nowMs: 0), 3);
    expect(budget.limit(from: 3, to: 6, nowMs: 1000), 4);
    budget.reset();
    expect(budget.limit(from: 4, to: 7, nowMs: 2000), 7);
  });
}
