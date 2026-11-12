import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

void main() {
  const normalizer = Normalizer();

  group('Normalizer', () {
    test('数字转中文读法', () {
      final tokens = normalizer.normalize('2026年增长80%，提升3.5倍');
      final text = tokens.map((t) => t.raw).join();
      expect(text, contains('二零二六'));
      expect(text, contains('百分之八十'));
      expect(text, contains('三点五'));
    });

    test('平翘舌与 n/l 合并到同一模糊类', () {
      expect(Normalizer.fuzzyOf('zhi'), Normalizer.fuzzyOf('zi'));
      expect(Normalizer.fuzzyOf('zhong'), Normalizer.fuzzyOf('zong'));
      expect(Normalizer.fuzzyOf('ni'), Normalizer.fuzzyOf('li'));
      expect(Normalizer.fuzzyOf('ying'), Normalizer.fuzzyOf('yin'));
    });
  });

  group('ScriptIndex', () {
    test('token 与行号映射正确', () {
      final index = ScriptIndex.build(['你好世界', '第二行内容']);
      expect(index.lineCount, 2);
      expect(index.lineOfToken(0), 0);
      expect(index.lineOfToken(3), 0);
      expect(index.lineOfToken(4), 1);
      expect(index.startTokenOfLine(1), 4);
    });
  });

  group('AlignEngine', () {
    final index = ScriptIndex.build([
      '今天我们来聊聊人工智能',
      '它正在改变我们的生活',
      '首先从语音识别开始',
    ]);
    final engine = AlignEngine(index);

    test('精确命中当前行', () {
      final result = engine.align('我们来聊聊人工智能', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      expect(result.confidence, greaterThan(0.65));
    });

    test('段内字符偏移随命中位置下沉', () {
      final result = engine.align('今天我们来聊聊人工智能', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      expect(result.anchorCharOffset, 10);
    });

    test('识别文本走到下一行时锚点随之前移', () {
      final result = engine.align('它正在改变我们的生活', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 1);
      expect(result.confidence, greaterThan(0.65));
    });

    test('同音字不影响定位', () {
      final homophoneIndex = ScriptIndex.build(['这是重点']);
      final result = AlignEngine(homophoneIndex).align('这是终点', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
    });

    test('空识别结果返回 null', () {
      expect(engine.align('   ', currentLine: 0), isNull);
    });
  });

  group('D2 锚点不落在未命中的段尾 token', () {
    test('段尾只能靠替换吃掉时，锚点停在最后一个真正命中的 token', () {
      final index = ScriptIndex.build([
        '这个功能依赖 Flutter 的插件体系，底层是 sherpa-onnx。',
        '我们把音频流交给 SDK。',
      ]);
      final result = AlignEngine(index).align(
        '这个功能依赖觉得插件体系底层是声音',
        currentLine: 0,
      );
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      // 末尾「声音」只能靠替换/删除吃掉 sherpa、onnx，不能把锚点钉到行尾。
      expect(result.anchorToken, 14);
      expect(result.anchorCharOffset, 23);
    });
  });

  group('AlignTracker', () {
    test('口误重读不回退：连续两次也不接受', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 5);
      final first = tracker.update(candidateLine: 2, rawConfidence: 0.9);
      expect(first.accepted, isFalse);
      expect(first.heldBack, isTrue);
      expect(tracker.line, 5);

      final second = tracker.update(candidateLine: 2, rawConfidence: 0.9);
      expect(second.accepted, isFalse);
      expect(second.heldBack, isTrue);
      expect(tracker.line, 5);
    });

    test('final 结果同样不回退，锚点单调向前', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 5);
      final update = tracker.update(
        candidateLine: 2,
        rawConfidence: 0.9,
        isFinal: true,
      );
      expect(update.accepted, isFalse);
      expect(update.heldBack, isTrue);
      expect(tracker.line, 5);
    });

    test('远处候选也要过置信底线，低置信不再白送', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 2);
      final update = tracker.update(candidateLine: 15, rawConfidence: 0.1);
      expect(update.accepted, isFalse);
      expect(tracker.line, 2);
    });

    test('大跨度前跳使用快速追赶', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 2);
      final update = tracker.update(
        candidateLine: 10,
        rawConfidence: 0.85,
        spanLength: 12,
      );
      expect(update.accepted, isTrue);
      expect(update.fastCatchUp, isTrue);
    });

    test('连续低置信进入降级态', () {
      final tracker = AlignTracker(lineCount: 20, initialLine: 0);
      for (var i = 0; i < 3; i++) {
        tracker.update(candidateLine: 0, rawConfidence: 0.2);
      }
      expect(tracker.degraded, isTrue);
      tracker.update(candidateLine: 0, rawConfidence: 0.7);
      expect(tracker.degraded, isFalse);
    });
  });
}
