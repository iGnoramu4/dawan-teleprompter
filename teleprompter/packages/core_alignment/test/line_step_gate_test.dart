import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

void main() {
  test('高置信命中下一行立即切行', () {
    final gate = LineStepGate();
    final decision = gate.evaluate(
      currentLine: 3,
      candidateLine: 4,
      confidence: 0.8,
    );
    expect(decision.advanced, isTrue);
    expect(decision.line, 4);
    expect(decision.leap, isFalse);
  });

  test('命中当前行不推进，行内保持稳定', () {
    final gate = LineStepGate();
    final decision = gate.evaluate(
      currentLine: 3,
      candidateLine: 3,
      confidence: 0.9,
    );
    expect(decision.advanced, isFalse);
    expect(decision.line, 3);
  });

  test('弱置信需要连续两次命中才切行', () {
    final gate = LineStepGate();
    final first = gate.evaluate(
      currentLine: 3,
      candidateLine: 4,
      confidence: 0.42,
    );
    expect(first.advanced, isFalse);
    expect(first.waiting, isTrue);

    final second = gate.evaluate(
      currentLine: 3,
      candidateLine: 4,
      confidence: 0.42,
    );
    expect(second.advanced, isTrue);
    expect(second.line, 4);
  });

  test('弱置信候选来回抖动不会误切行', () {
    final gate = LineStepGate();
    gate.evaluate(currentLine: 3, candidateLine: 4, confidence: 0.42);
    final back = gate.evaluate(
      currentLine: 3,
      candidateLine: 3,
      confidence: 0.42,
    );
    expect(back.advanced, isFalse);
    final next = gate.evaluate(
      currentLine: 3,
      candidateLine: 4,
      confidence: 0.42,
    );
    expect(next.advanced, isFalse);
    expect(next.waiting, isTrue);
  });

  test('低置信不推进，连续三次进入降级态', () {
    final gate = LineStepGate();
    for (var i = 0; i < 3; i++) {
      final decision = gate.evaluate(
        currentLine: 3,
        candidateLine: 4,
        confidence: 0.2,
      );
      expect(decision.advanced, isFalse);
      expect(decision.lowConfidence, isTrue);
      expect(decision.degraded, i == 2);
    }
  });

  test('final 结果带置信度加成', () {
    final gate = LineStepGate();
    final decision = gate.evaluate(
      currentLine: 3,
      candidateLine: 4,
      confidence: 0.42,
      isFinal: true,
    );
    expect(decision.advanced, isTrue);
    expect(decision.line, 4);
  });

  test('越级跳转单次最多前进 maxLeap 行', () {
    final gate = LineStepGate(maxLeap: 3);
    final decision = gate.evaluate(
      currentLine: 2,
      candidateLine: 12,
      confidence: 0.9,
      spanLength: 12,
    );
    expect(decision.advanced, isTrue);
    expect(decision.line, 5);
    expect(decision.leap, isTrue);
  });

  test('远处候选低置信不再白送 maxLeap 行', () {
    final gate = LineStepGate(maxLeap: 3);
    final first = gate.evaluate(
      currentLine: 2,
      candidateLine: 12,
      confidence: 0.12,
    );
    expect(first.advanced, isFalse);
    expect(first.line, 2);
    expect(first.lowConfidence, isTrue);

    final second = gate.evaluate(
      currentLine: 2,
      candidateLine: 12,
      confidence: 0.12,
    );
    expect(second.advanced, isFalse);
    expect(second.line, 2);
  });

  test('远处候选弱置信连续两次仍只逐行推进', () {
    final gate = LineStepGate(maxLeap: 3);
    final first = gate.evaluate(
      currentLine: 2,
      candidateLine: 12,
      confidence: 0.42,
      spanLength: 12,
    );
    expect(first.advanced, isFalse);
    expect(first.waiting, isTrue);

    final second = gate.evaluate(
      currentLine: 2,
      candidateLine: 12,
      confidence: 0.42,
      spanLength: 12,
    );
    expect(second.advanced, isTrue);
    expect(second.line, 3);
    expect(second.leap, isFalse);
  });

  test('短跨度（<6 音节）即便高置信也只前进一行', () {
    final gate = LineStepGate(maxLeap: 3);
    final decision = gate.evaluate(
      currentLine: 2,
      candidateLine: 6,
      confidence: 0.9,
      spanLength: 3,
    );
    expect(decision.advanced, isTrue);
    expect(decision.line, 3);
  });

  test('次高置信（<0.8）即便长跨度也只前进一行', () {
    final gate = LineStepGate(maxLeap: 3);
    final decision = gate.evaluate(
      currentLine: 2,
      candidateLine: 6,
      confidence: 0.7,
      spanLength: 20,
    );
    expect(decision.advanced, isTrue);
    expect(decision.line, 3);
  });

  test('回退候选不触发回跳', () {
    final gate = LineStepGate();
    final decision = gate.evaluate(
      currentLine: 5,
      candidateLine: 2,
      confidence: 0.95,
      isFinal: true,
    );
    expect(decision.advanced, isFalse);
    expect(decision.line, 5);
  });
}
