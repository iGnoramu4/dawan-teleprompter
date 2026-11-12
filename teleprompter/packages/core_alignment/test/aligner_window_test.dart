import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

/// 长段落 + 端点重置（每 20 个音节一条 utterance）下的窗口稳定性。
///
/// 曾经的问题：DP 窗口钉在行首，行首前缀的删除代价让对齐选一条短而错的
/// 路径，锚点卡在行首附近（长段落卡住），读到下一段又整段跳（跳读）。
void main() {
  late List<String> units;
  late List<String> lines;
  late ScriptIndex index;
  late AlignTracker tracker;
  late AlignEngine aligner;

  setUp(() {
    units = <String>[
      for (var i = 0; i < 300; i++)
        String.fromCharCode(0x4e00 + (i * 37) % 2000),
    ];
    lines = <String>[units.join(), '这是下一段的第一句话', '第三段内容'];
    index = ScriptIndex.build(lines);
    tracker = AlignTracker.fromProfile(
      MatchProfile.standardProfile,
      lineCount: lines.length,
    );
    aligner = AlignEngine(index, lookAheadLines: 3);
  });

  test('长段落按端点分段朗读时锚点单调前进', () {
    var lastChar = 0;
    for (var start = 0; start < 260; start += 20) {
      final text = units.sublist(start, start + 20).join();
      final align = aligner.align(
        text,
        currentLine: tracker.line,
        currentCharOffset: lastChar,
      );
      expect(align, isNotNull, reason: 'start=$start 应能对齐');
      expect(align!.anchorLine, 0);
      expect(align.anchorCharOffset, greaterThan(lastChar),
          reason: 'start=$start 锚点必须前进（曾卡在行首）');
      expect(align.confidence, greaterThan(0.6),
          reason: 'start=$start 置信不应掉到噪声级');
      tracker.update(
        candidateLine: align.anchorLine,
        rawConfidence: align.confidence,
        isFinal: true,
      );
      lastChar = align.anchorCharOffset;
    }
    expect(lastChar, greaterThan(250));
  });

  test('段落中途开始朗读（跳过前 100 字）仍对齐到真实位置', () {
    final text = units.sublist(100, 120).join();
    final align = aligner.align(
      text,
      currentLine: 0,
      currentCharOffset: 0, // 没有阅读位置提示时仍可能偏行首
    );
    expect(align, isNotNull);
    // 有阅读位置提示：从第 100 字继续读，窗口应落在真实位置附近。
    final hinted = aligner.align(
      text,
      currentLine: 0,
      currentCharOffset: 100,
    );
    expect(hinted, isNotNull);
    expect(hinted!.anchorCharOffset, greaterThanOrEqualTo(110));
    expect(hinted.confidence, greaterThan(0.6));
    expect(align!.confidence, lessThan(hinted.confidence + 1));
  });

  test('行内位置提示不会把锚点推到错误行', () {
    final align = aligner.align(
      '这是下一段的第一句话',
      currentLine: 0,
      currentCharOffset: 290,
    );
    expect(align, isNotNull);
    expect(align!.anchorLine, 1);
  });

  test('跨行后沿用上一行的字符偏移，窗口不会越过当前行', () {
    // 真机场景：跟踪器已内部前移到第 1 行，阅读位置还停在第 0 行的第 290 字。
    // 旧实现把越界偏移解释成「第 1 行行首之后很远」，窗口直接落到第 2 行，
    // DP 只能去更后面找词，产生「低置信但一直往前跳」的连锁。
    final align = aligner.align(
      '这是下一段的第一句话',
      currentLine: 1,
      currentCharOffset: 290,
    );
    expect(align, isNotNull);
    expect(align!.anchorLine, 1, reason: '窗口必须锚在第 1 行，不能滑到第 2 行');
    expect(align.anchorCharOffset, lessThan(12));
    expect(align.confidence, greaterThan(0.6));
  });

  test('单条长分句（超过带宽 40 音节）仍能对齐到已说位置', () {
    // 真机场景：端点前 ASR 文本一直累积，一条分句可以长达 20 秒（100+ 音节）。
    // 旧实现把窗口钉在阅读位置，真实路径落到 |i-j|<=40 的带宽之外，DP 只能
    // 把文本尾巴对到后面几行（锚点棘轮前跳、置信掉到 0.2，滚行冻结）。
    var lastChar = 0;
    for (var n = 5; n <= 120; n += 5) {
      final align = aligner.align(
        units.sublist(0, n).join(),
        currentLine: 0,
        currentCharOffset: lastChar,
      );
      expect(align, isNotNull, reason: 'n=$n 必须给出对齐结果（不能因带宽返回空）');
      expect(align!.anchorLine, 0, reason: 'n=$n 不应滑到下一行');
      expect(align.anchorCharOffset, greaterThanOrEqualTo(n - 3),
          reason: 'n=$n 锚点应跟到文本末尾附近');
      expect(align.anchorCharOffset, lessThanOrEqualTo(n + 2),
          reason: 'n=$n 锚点不得超前于已说内容');
      expect(align.confidence, greaterThan(0.6), reason: 'n=$n 置信不应掉到噪声级');
      lastChar = align.anchorCharOffset;
    }
  });
}
