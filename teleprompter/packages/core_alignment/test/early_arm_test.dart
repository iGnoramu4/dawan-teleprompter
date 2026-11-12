import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

void main() {
  const normalizer = Normalizer();
  const currentLine = '今天我们来聊一聊提词器';
  const nextLine = '下一行开头是重点内容';
  late ScriptIndex index;

  setUp(() {
    index = ScriptIndex.build([currentLine, nextLine, '第三行结尾']);
  });

  int start() => index.startTokenOfLine(0);
  int end() => index.endTokenOfLine(0);
  int tokensInLine() => end() - start();

  int anchorAt(double fraction) {
    final count = tokensInLine();
    return start() + (count * fraction).ceil() - 1;
  }

  List<NormToken> spoken(String text) => normalizer.normalize(text);

  test('严格档关闭 early arm', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.strictProfile,
    );
    expect(detector.enabled, isFalse);
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: end() - 1,
      spoken: spoken('随便下一'),
      isFinal: true,
    );
    expect(decision.armed, isFalse);
    expect(decision.line, 0);
  });

  test('当前行已读比例不足 0.55 时不触发', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: anchorAt(0.5),
      spoken: spoken('随便下一'),
      isFinal: true,
    );
    expect(decision.armed, isFalse);
  });

  test('前缀命中需连续 2 次才提前跨行', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    final first = detector.evaluate(
      currentLine: 0,
      anchorToken: end() - 1,
      spoken: spoken('随便下一'),
      isFinal: false,
    );
    expect(first.armed, isFalse);
    expect(first.line, 0);

    final second = detector.evaluate(
      currentLine: 0,
      anchorToken: end() - 1,
      spoken: spoken('随便下一'),
      isFinal: false,
    );
    expect(second.armed, isTrue);
    expect(second.line, 1);
  });

  test('final 结果一次命中即可提前跨行', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: end() - 1,
      spoken: spoken('随便下一'),
      isFinal: true,
    );
    expect(decision.armed, isTrue);
    expect(decision.line, 1);
  });

  test('下一行前缀不匹配时不触发', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    for (var i = 0; i < 5; i++) {
      final decision = detector.evaluate(
        currentLine: 0,
        anchorToken: end() - 1,
        spoken: spoken('随便最后'),
        isFinal: true,
      );
      expect(decision.armed, isFalse);
    }
  });

  test('末行没有下一行时不触发', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    final decision = detector.evaluate(
      currentLine: index.lineCount - 1,
      anchorToken: index.tokenCount - 1,
      spoken: spoken('随便下一'),
      isFinal: true,
    );
    expect(decision.armed, isFalse);
  });

  test('replaceIndex 清空连续命中，不会沿用旧索引的计数', () {
    final detector = EarlyArmDetector.fromProfile(
      index,
      MatchProfile.standardProfile,
    );
    detector.evaluate(
      currentLine: 0,
      anchorToken: end() - 1,
      spoken: spoken('随便下一'),
      isFinal: false,
    );
    final replacement = ScriptIndex.build([currentLine, nextLine]);
    detector.replaceIndex(replacement);
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: replacement.endTokenOfLine(0) - 1,
      spoken: spoken('随便下一'),
      isFinal: false,
    );
    expect(decision.armed, isFalse);
  });

  test('短尾捷径：两段都很短且被识别尾部覆盖时一次瞄准两段之后', () {
    final shortIndex = ScriptIndex.build(['甲乙丙丁', '好', '谢谢']);
    final detector = EarlyArmDetector(index: shortIndex);
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: shortIndex.endTokenOfLine(0) - 1,
      spoken: spoken('好谢谢'),
      isFinal: true,
    );
    expect(decision.armed, isTrue);
    expect(decision.line, 2);
  });

  test('短尾捷径不跨过未被尾部覆盖的第三段', () {
    final shortIndex = ScriptIndex.build(['甲乙丙丁', '好', '另外一句话']);
    final detector = EarlyArmDetector(index: shortIndex);
    final decision = detector.evaluate(
      currentLine: 0,
      anchorToken: shortIndex.endTokenOfLine(0) - 1,
      spoken: spoken('好'),
      isFinal: true,
    );
    expect(decision.armed, isTrue);
    expect(decision.line, 1);
  });
}
