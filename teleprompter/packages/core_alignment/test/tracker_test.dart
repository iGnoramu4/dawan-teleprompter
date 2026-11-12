import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

void main() {
  group('低置信跨行防棘轮', () {
    test('真机 3→5→7→10：漂移候选每次最多前进一行', () {
      final tracker = AlignTracker.fromProfile(
        MatchProfile.looseProfile,
        lineCount: 20,
        initialLine: 3,
      );

      var line = 3;
      for (final candidate in [5, 7, 10]) {
        final update = tracker.update(
          candidateLine: candidate,
          rawConfidence: 0.24,
          spanLength: 12,
        );
        expect(update.accepted, isTrue);
        expect(update.line - line, lessThanOrEqualTo(1));
        line = update.line;
      }
      // 三次漂移候选最多从 3 走到 6，不会冲到 10。
      expect(line, lessThanOrEqualTo(6));
    });

    test('低置信远候选连续出现也只逐行推进', () {
      final tracker = AlignTracker(
        lineCount: 20,
        initialLine: 2,
        leapConfidence: 0.6,
      );

      final first = tracker.update(
        candidateLine: 8,
        rawConfidence: 0.24,
        spanLength: 12,
      );
      expect(first.line, 3);
      expect(first.fastCatchUp, isFalse);

      final second = tracker.update(
        candidateLine: 8,
        rawConfidence: 0.24,
        spanLength: 12,
      );
      expect(second.line, 4);
      expect(second.fastCatchUp, isFalse);
    });

    test('高置信长跨度候选仍可单次跨行，但不超过 3 行', () {
      final tracker = AlignTracker(
        lineCount: 20,
        initialLine: 2,
        leapConfidence: 0.6,
      );
      final update = tracker.update(
        candidateLine: 8,
        rawConfidence: 0.85,
        spanLength: 12,
      );
      expect(update.line, 5);
    });
  });

  group('短跨度/次高置信只逐行推进', () {
    test('span<6 即便高置信也只前进一行', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 2);
      final update = tracker.update(
        candidateLine: 8,
        rawConfidence: 0.95,
        spanLength: 3,
      );
      expect(update.line, 3);
    });

    test('conf<0.8 即便长跨度也只前进一行', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 2);
      final update = tracker.update(
        candidateLine: 8,
        rawConfidence: 0.7,
        spanLength: 20,
      );
      expect(update.line, 3);
    });

    test('真机抢跑样本：span=3/conf=0.67 不再一次跳到 6 行', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 3);
      final update = tracker.update(
        candidateLine: 6,
        rawConfidence: 0.67,
        spanLength: 3,
      );
      expect(update.line, 4);
    });
  });

  group('reset 清掉锚点行', () {
    test('reset 后行号归零，重新 forceLine 才恢复', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 9);
      expect(tracker.line, 9);
      tracker.reset();
      expect(tracker.line, 0);
      tracker.forceLine(4);
      expect(tracker.line, 4);
    });
  });
}
