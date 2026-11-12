import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

const _normalizer = Normalizer();

List<NormToken> _tokens(String text) => _normalizer.normalize(text);

void main() {
  group('行级覆盖率', () {
    test('短行（5 音节）漏 1 个字不放行，全读才放行', () {
      final index = ScriptIndex.build(['今天开始演']);
      final tracker = LineCoverageTracker(index);
      final partial = tracker.update(0, _tokens('今天开始'));
      expect(partial.total, 5);
      expect(tracker.allowsAdvance(partial), isFalse);
      final full = tracker.update(0, _tokens('演'));
      expect(full.matched, 5);
      expect(tracker.allowsAdvance(full), isTrue);
    });

    test('长行允许少量漏读/错读，覆盖达标即放行', () {
      const line = '第一部分负责采集第二部分负责识别第三部分负责把结果映射到稿件位置';
      final index = ScriptIndex.build([line]);
      final tracker = LineCoverageTracker(index);
      // 跳过 3 个音节后继续读完整行。
      final cover = tracker.update(0, _tokens(line));
      expect(cover.ratio, 1.0);
      expect(tracker.allowsAdvance(cover), isTrue);
    });

    test('只读到行首关键词不放行（最远命中位置不够）', () {
      const line = '第一部分负责采集第二部分负责识别第三部分负责把结果映射到稿件位置';
      final index = ScriptIndex.build([line]);
      final tracker = LineCoverageTracker(index);
      final cover = tracker.update(0, _tokens('第一部分负责采集第二部分负责'));
      expect(cover.ratio, lessThan(0.5));
      expect(tracker.allowsAdvance(cover), isFalse);
    });

    test('只命中行尾零散词不放行（单调 + 最远位置双条件）', () {
      const line = '第一部分负责采集第二部分负责识别第三部分负责把结果映射到稿件位置';
      final index = ScriptIndex.build([line]);
      final tracker = LineCoverageTracker(index);
      final cover = tracker.update(0, _tokens('稿件位置'));
      expect(cover.matched, lessThan(3));
      expect(tracker.allowsAdvance(cover), isFalse);
    });

    test('乱序命中不计入，噪声难以拼出高覆盖', () {
      const line = '第一部分负责采集第二部分负责识别第三部分负责把结果映射到稿件位置';
      final index = ScriptIndex.build([line]);
      final tracker = LineCoverageTracker(index);
      final cover = tracker.update(
        0,
        _tokens('稿件位置映射结果把负责部分第三'),
      );
      expect(cover.ratio, lessThan(0.4));
      expect(tracker.allowsAdvance(cover), isFalse);
    });

    test('换行后重新计数', () {
      final index = ScriptIndex.build(['今天开始演示', '明天继续讲第二部分']);
      final tracker = LineCoverageTracker(index);
      expect(
          tracker.allowsAdvance(tracker.update(0, _tokens('今天开始演示'))), isTrue);
      final next = tracker.update(1, _tokens('明天'));
      expect(next.line, 1);
      expect(next.matched, 2);
      expect(tracker.allowsAdvance(next), isFalse);
    });
  });

  group('跳读硬上限不变量', () {
    test('硬上限常量就是 3 行', () {
      expect(maxAutoLeapLines, 3);
    });

    test('闸门：候选越级也被压到 3 行以内', () {
      final gate = LineStepGate.fromProfile(MatchProfile.standardProfile);
      final decision = gate.evaluate(
        currentLine: 0,
        candidateLine: 20,
        confidence: 1,
        isFinal: true,
        spanLength: 20,
      );
      expect(decision.advanced, isTrue);
      expect(decision.line - 0, lessThanOrEqualTo(maxAutoLeapLines));
    });

    test('闸门构造参数不能突破硬上限', () {
      final gate = LineStepGate(maxLeap: 99);
      expect(gate.maxLeap, maxAutoLeapLines);
    });

    test('宽松档位也不能超过 3 行', () {
      expect(MatchProfile.looseProfile.maxLeap, lessThanOrEqualTo(3));
      final gate = LineStepGate.fromProfile(MatchProfile.looseProfile);
      final decision = gate.evaluate(
        currentLine: 5,
        candidateLine: 50,
        confidence: 1,
        isFinal: true,
        spanLength: 20,
      );
      expect(decision.line - 5, lessThanOrEqualTo(maxAutoLeapLines));
    });

    test('跟踪器：高置信远候选同样被压到 3 行', () {
      final tracker = AlignTracker.fromProfile(
        MatchProfile.standardProfile,
        lineCount: 100,
      );
      final update = tracker.update(
        candidateLine: 80,
        rawConfidence: 1,
        spanLength: 20,
      );
      expect(update.line, maxAutoLeapLines);
    });
  });

  group('连续朗读自适应', () {
    test('连续有输出且推进后进入放宽态，静音后退出', () {
      final monitor = ContinuousSpeechMonitor();
      final start = DateTime.utc(2026, 11, 11, 10);
      for (var i = 0; i < 5; i++) {
        monitor.onUpdate(
          at: start.add(Duration(milliseconds: 800 * i)),
          confidence: 0.6,
          line: i,
        );
      }
      expect(monitor.relaxed, isTrue);
      monitor.tick(start.add(const Duration(seconds: 6)));
      expect(monitor.relaxed, isFalse);
    });

    test('低置信堆积退出放宽态', () {
      final monitor = ContinuousSpeechMonitor();
      final start = DateTime.utc(2026, 11, 11, 10);
      for (var i = 0; i < 5; i++) {
        monitor.onUpdate(
          at: start.add(Duration(milliseconds: 800 * i)),
          confidence: 0.6,
          line: i,
        );
      }
      expect(monitor.relaxed, isTrue);
      var at = start.add(const Duration(milliseconds: 4000));
      for (var i = 0; i < 3; i++) {
        monitor.onUpdate(at: at, confidence: 0.1, line: 5);
        at = at.add(const Duration(milliseconds: 800));
      }
      expect(monitor.relaxed, isFalse);
    });

    test('未达标（无推进）不进入放宽态', () {
      final monitor = ContinuousSpeechMonitor();
      final start = DateTime.utc(2026, 11, 11, 10);
      for (var i = 0; i < 8; i++) {
        monitor.onUpdate(
          at: start.add(Duration(milliseconds: 800 * i)),
          confidence: 0.6,
          line: 0,
        );
      }
      expect(monitor.relaxed, isFalse);
    });

    test('关闭自适应时恒不放宽', () {
      final monitor = ContinuousSpeechMonitor(enabled: false);
      final start = DateTime.utc(2026, 11, 11, 10);
      for (var i = 0; i < 8; i++) {
        monitor.onUpdate(
          at: start.add(Duration(milliseconds: 800 * i)),
          confidence: 0.9,
          line: i,
        );
      }
      expect(monitor.relaxed, isFalse);
    });

    test('闸门放宽：阈值下调、弱命中次数减 1', () {
      final gate = LineStepGate();
      expect(gate.effectiveWeakHits, 2);
      gate.relaxed = true;
      expect(gate.effectiveConfirm, lessThan(gate.confirmConfidence));
      expect(gate.effectiveWeak, lessThan(gate.weakConfidence));
      expect(gate.effectiveWeakHits, 1);
      // 0.32 在标准档属于弱命中（<0.35），放宽后一次即放行。
      final decision = gate.evaluate(
        currentLine: 0,
        candidateLine: 1,
        confidence: 0.32,
      );
      expect(decision.advanced, isTrue);
    });

    test('放宽切换会清空待确认的弱命中，避免旧证据带过来', () {
      final gate = LineStepGate();
      final first = gate.evaluate(
        currentLine: 0,
        candidateLine: 1,
        confidence: 0.36,
      );
      expect(first.advanced, isFalse);
      gate.relaxed = true;
      gate.relaxed = false;
      final after = gate.evaluate(
        currentLine: 0,
        candidateLine: 1,
        confidence: 0.36,
      );
      expect(after.advanced, isFalse);
    });
  });
}
