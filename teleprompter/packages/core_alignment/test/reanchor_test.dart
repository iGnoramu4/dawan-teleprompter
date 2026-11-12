import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

const _phrase = '数据接口稳定';

/// 长行台本：让「正常 200 token 窗口」打不到后半行，但行号仍在 +3 以内。
ScriptIndex _longLineIndex() {
  return ScriptIndex.build([
    '零' * 250,
    '零' * 350 + _phrase,
    '零' * 100,
  ]);
}

/// 远行台本：目标行在 currentLine+5，重定位必须只给建议行、不改位置。
ScriptIndex _farLineIndex() {
  final lines = List<String>.filled(7, '零' * 200);
  lines[5] = '零' * 20 + _phrase + '零' * 174;
  return ScriptIndex.build(lines);
}

void main() {
  group('等待与未命中', () {
    test('端点后少于 3 个音节记为等待，不推进位置', () {
      final engine = AlignEngine(ScriptIndex.build(['数据接口稳定']));
      final result = engine.align('你', currentLine: 0)!;
      expect(result.matched, isFalse);
      expect(result.pending, isTrue);
      expect(result.anchorLine, 0);
      expect(result.confidence, 0);
    });

    test('未命中快照不改变 tracker 状态', () {
      final tracker = AlignTracker(lineCount: 5, initialLine: 2);
      tracker.update(candidateLine: 2, rawConfidence: 0.9);
      final before = tracker.line;
      final snapshot = tracker.snapshot();
      expect(snapshot.line, before);
      expect(snapshot.accepted, isFalse);
      expect(tracker.line, before);
    });
  });

  group('失败重定位', () {
    test('连续未命中后在 +3 行内重新锚定', () {
      final engine = AlignEngine(_longLineIndex());

      final first = engine.align(_phrase, currentLine: 0)!;
      expect(first.matched, isFalse);
      expect(first.pending, isFalse);

      final second = engine.align(_phrase, currentLine: 0)!;
      expect(second.matched, isFalse);

      final third = engine.align(_phrase, currentLine: 0)!;
      expect(third.matched, isTrue);
      expect(third.reanchored, isTrue);
      expect(third.anchorLine, 1);
      expect(third.confidence, greaterThanOrEqualTo(0.8));
    });

    test('重锚落点超过当前行 +3 时只给建议行，不改变位置', () {
      final engine = AlignEngine(_farLineIndex());

      for (var i = 0; i < 2; i++) {
        final result = engine.align(_phrase, currentLine: 0)!;
        expect(result.matched, isFalse);
        expect(result.suggestedLine, -1);
      }

      final blocked = engine.align(_phrase, currentLine: 0)!;
      expect(blocked.matched, isFalse);
      expect(blocked.reanchored, isFalse);
      expect(blocked.anchorLine, 0);
      expect(blocked.suggestedLine, 5);
    });

    test('一次重锚后必须先出现正常命中，不能连续重锚', () {
      final engine = AlignEngine(_longLineIndex());
      for (var i = 0; i < 3; i++) {
        engine.align(_phrase, currentLine: 0);
      }

      // 冷却期内即使继续卡住，也绝不再跳。
      for (var i = 0; i < 3; i++) {
        final result = engine.align(_phrase, currentLine: 1)!;
        expect(result.matched, isFalse);
        expect(result.reanchored, isFalse);
        expect(result.anchorLine, 1);
      }
    });

    test('重锚永远不超过 3 行（多行长脚本回归）', () {
      final engine = AlignEngine(_farLineIndex());
      var line = 0;
      for (var i = 0; i < 9; i++) {
        final result = engine.align(_phrase, currentLine: line)!;
        if (result.reanchored) {
          expect(result.anchorLine - line, lessThanOrEqualTo(3));
          line = result.anchorLine;
        }
      }
      expect(line, lessThanOrEqualTo(3));
    });
  });
}
