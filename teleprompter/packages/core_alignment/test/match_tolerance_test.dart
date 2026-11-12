import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

void main() {
  group('MatchTolerance', () {
    test('三档参数单调递减', () {
      const strict = MatchProfile.strictProfile;
      const standard = MatchProfile.standardProfile;
      const loose = MatchProfile.looseProfile;
      expect(
        strict.confirmConfidence,
        greaterThan(standard.confirmConfidence),
      );
      expect(
        standard.confirmConfidence,
        greaterThan(loose.confirmConfidence),
      );
      expect(strict.weakConfidence, greaterThan(standard.weakConfidence));
      expect(standard.weakConfidence, greaterThan(loose.weakConfidence));
      expect(strict.lookAheadLines, lessThan(standard.lookAheadLines));
      expect(standard.lookAheadLines, lessThan(loose.lookAheadLines));
      expect(strict.maxLeap, lessThanOrEqualTo(standard.maxLeap));
      expect(standard.maxLeap, lessThanOrEqualTo(loose.maxLeap));
    });

    test('标准档保留历史阈值', () {
      const profile = MatchProfile.standardProfile;
      expect(profile.confirmConfidence, 0.55);
      expect(profile.weakConfidence, 0.35);
      expect(profile.finalBonus, 0.15);
      expect(profile.lookAheadLines, 3);
      expect(profile.acceptFloor, 0.20);
      expect(profile.recoverConfidence, 0.50);
    });

    test('of() 与档位对应', () {
      expect(
        MatchProfile.of(MatchTolerance.strict).tolerance,
        MatchTolerance.strict,
      );
      expect(
        MatchProfile.of(MatchTolerance.standard),
        same(MatchProfile.standardProfile),
      );
      expect(
        MatchProfile.of(MatchTolerance.loose).tolerance,
        MatchTolerance.loose,
      );
    });

    test('parse 容错并回落到标准档', () {
      expect(MatchProfile.parse('strict'), MatchTolerance.strict);
      expect(MatchProfile.parse('loose'), MatchTolerance.loose);
      expect(MatchProfile.parse('unknown'), MatchTolerance.standard);
      expect(MatchProfile.parse(null), MatchTolerance.standard);
      expect(MatchProfile.parse(3), MatchTolerance.standard);
    });

    test('五档阈值从谨慎到宽松单调放宽', () {
      final profiles =
          MatchTolerance.values.map(MatchProfile.of).toList(growable: false);
      for (var i = 1; i < profiles.length; i++) {
        expect(
          profiles[i].confirmConfidence,
          lessThanOrEqualTo(profiles[i - 1].confirmConfidence),
        );
        expect(
          profiles[i].weakConfidence,
          lessThanOrEqualTo(profiles[i - 1].weakConfidence),
        );
        expect(
          profiles[i].maxLeap,
          greaterThanOrEqualTo(profiles[i - 1].maxLeap),
        );
      }
      expect(MatchTolerance.values.length, 5);
      expect(MatchProfile.of(MatchTolerance.veryLoose).maxLeap, 3);
      expect(MatchProfile.of(MatchTolerance.veryStrict).maxLeap, 1);
    });
  });

  group('档位驱动 LineStepGate', () {
    test('标准档 0.55 立即推进', () {
      final gate = LineStepGate.fromProfile(MatchProfile.standardProfile);
      final decision = gate.evaluate(
        currentLine: 2,
        candidateLine: 3,
        confidence: 0.56,
      );
      expect(decision.advanced, isTrue);
      expect(decision.line, 3);
    });

    test('严格档 0.56 不推进，0.72 才推进', () {
      final gate = LineStepGate.fromProfile(MatchProfile.strictProfile);
      final weak = gate.evaluate(
        currentLine: 2,
        candidateLine: 3,
        confidence: 0.56,
      );
      expect(weak.advanced, isFalse);
      expect(weak.waiting, isTrue);
      final strong = gate.evaluate(
        currentLine: 2,
        candidateLine: 3,
        confidence: 0.72,
      );
      expect(strong.advanced, isTrue);
    });

    test('宽松档 0.45 一次即推进', () {
      final gate = LineStepGate.fromProfile(MatchProfile.looseProfile);
      final decision = gate.evaluate(
        currentLine: 2,
        candidateLine: 3,
        confidence: 0.45,
      );
      expect(decision.advanced, isTrue);
      expect(decision.line, 3);
    });

    test('宽松档允许更大的单次跳跃', () {
      final gate = LineStepGate.fromProfile(MatchProfile.looseProfile);
      final decision = gate.evaluate(
        currentLine: 0,
        candidateLine: 9,
        confidence: 0.9,
        spanLength: 20,
      );
      expect(decision.leap, isTrue);
      expect(decision.line, MatchProfile.looseProfile.maxLeap);
    });
  });

  group('档位驱动 AlignTracker', () {
    test('fromProfile 采用档位阈值', () {
      final tracker = AlignTracker.fromProfile(
        MatchProfile.looseProfile,
        lineCount: 10,
      );
      expect(tracker.weakConfidence, MatchProfile.looseProfile.weakConfidence);
      expect(tracker.acceptFloor, MatchProfile.looseProfile.acceptFloor);
      expect(
        tracker.recoverConfidence,
        MatchProfile.looseProfile.recoverConfidence,
      );
    });

    test('applyProfile 保留当前锚点', () {
      final tracker = AlignTracker.fromProfile(
        MatchProfile.standardProfile,
        lineCount: 10,
      );
      tracker.forceLine(4);
      tracker.applyProfile(MatchProfile.strictProfile);
      expect(tracker.line, 4);
      expect(tracker.acceptFloor, MatchProfile.strictProfile.acceptFloor);
    });

    test('严格档拒绝标准档可接受的低置信候选', () {
      final standard = AlignTracker.fromProfile(
        MatchProfile.standardProfile,
        lineCount: 10,
      );
      final strict = AlignTracker.fromProfile(
        MatchProfile.strictProfile,
        lineCount: 10,
      );
      final standardUpdate = standard.update(
        candidateLine: 1,
        rawConfidence: 0.25,
      );
      final strictUpdate = strict.update(
        candidateLine: 1,
        rawConfidence: 0.25,
      );
      expect(standardUpdate.accepted, isTrue);
      expect(strictUpdate.accepted, isFalse);
      expect(strictUpdate.heldBack, isTrue);
    });
  });

  group('档位驱动 AlignEngine', () {
    test('前看行数与预筛底线可注入', () {
      final engine = AlignEngine(
        ScriptIndex.build(const ['第一行', '第二行']),
        lookAheadLines: 3,
        minScore: 0.4,
      );
      expect(engine.lookAheadLines, 3);
      expect(engine.minScore, 0.4);
    });

    test('前看过窄时远处的精确文本不会被锚点窗口覆盖', () {
      final lines = List.generate(20, (i) => '这是第${i + 1}行的测试文本');
      final engine = AlignEngine(
        ScriptIndex.build(lines),
        windowW: 6,
        lookAheadLines: 2,
        minScore: 0.9,
      );
      final result = engine.align('这是第18行的测试文本', currentLine: 0);
      expect(result == null || result.anchorLine < 17, isTrue);
    });
  });
}
