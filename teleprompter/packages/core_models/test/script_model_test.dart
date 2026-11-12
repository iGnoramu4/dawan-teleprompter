import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

void main() {
  group('分段与断行', () {
    test('按空行分段，段内不再按标点断行', () {
      const raw = '第一段第一句。第一段第二句！\n\n第二段只有一句。';
      final script = ScriptModel.parse(id: 'demo', title: '示例', rawText: raw);
      expect(script.lines.map((line) => line.text).toList(), [
        '第一段第一句。第一段第二句！',
        '第二段只有一句。',
      ]);
      expect(script.lines[0].sectionCharStart, 0);
      expect(script.lines[1].sectionCharStart, 0);
    });

    test('超长段内文本仍是一条语义行（交给排版自然折行）', () {
      final script = ScriptModel.parse(
        id: 'long',
        title: '长段',
        rawText: '这是一个很长很长的句子，它需要被切成两行，方便提词器展示。',
      );
      expect(script.lines.length, 1);
      expect(script.lines.single.text.contains('，'), isTrue);
    });

    test('空文本得到空行列表', () {
      final script =
          ScriptModel.parse(id: 'empty', title: '空', rawText: ' \n\n ');
      expect(script.lines, isEmpty);
      expect(script.charCount, 0);
    });

    test('没有空行时整篇为一段，不按句号/长度切分', () {
      const sentence = '这是用于测试的一句话。';
      final raw = List.generate(20, (_) => sentence).join();
      final sections = splitIntoSections(raw);
      expect(sections, [raw]);
    });

    test('多个空行分段并去除首尾空白', () {
      const raw = '第一段。\n\n\n第二段，仍在同一段。\n\n第三段！';
      expect(splitIntoSections(raw), ['第一段。', '第二段，仍在同一段。', '第三段！']);
    });

    test('从分段渲染时每个分段就是一条语义行', () {
      const sections = [
        ScriptSection(id: 'a', scriptId: 's', ord: 0, text: '第一句。第二句。'),
        ScriptSection(id: 'b', scriptId: 's', ord: 1, text: '第三句。'),
      ];
      final model = ScriptModel.fromSections(
        id: 's',
        title: 't',
        rawText: '第一句。第二句。\n\n第三句。',
        sections: sections,
      );
      expect(model.lines.length, 2);
      expect(model.lines[0].sectionId, 'a');
      expect(model.lines[0].sectionCharStart, 0);
      expect(model.lines[0].text, '第一句。第二句。');
      expect(model.lines[1].sectionId, 'b');
    });

    test('旧版按句切行的锚点折算到段落模型', () {
      const sections = [
        ScriptSection(id: 'a', scriptId: 's', ord: 0, text: '第一句。第二句。'),
        ScriptSection(id: 'b', scriptId: 's', ord: 1, text: '第三句。'),
      ];
      final lines = ScriptModel.fromSections(
        id: 's',
        title: 't',
        rawText: '第一句。第二句。\n\n第三句。',
        sections: sections,
      ).lines;
      final second = mapLegacyAnchorToParagraphs(
        sections: sections,
        lines: lines,
        legacyAnchor: 1,
      );
      expect(second.line, 0);
      expect(second.charOffset, 4);
      final third = mapLegacyAnchorToParagraphs(
        sections: sections,
        lines: lines,
        legacyAnchor: 2,
      );
      expect(third.line, 1);
      expect(third.charOffset, 0);
    });
  });

  group('标记映射', () {
    const sections = [
      ScriptSection(id: 'a', scriptId: 's', ord: 0, text: '第一句。第二句。'),
    ];
    final lines = ScriptModel.fromSections(
      id: 's',
      title: 't',
      rawText: '第一句。第二句。',
      sections: sections,
    ).lines;

    test('offset 落在段内任意位置都映射到该段', () {
      const markers = [
        ScriptMarker(
          id: 'm1',
          scriptId: 's',
          sectionId: 'a',
          charOffset: 4,
          kind: MarkerKind.emphasis,
        ),
      ];
      final mapped = mapMarkersToLines(
        sections: sections,
        markers: markers,
        lines: lines,
      );
      expect(mapped[0]?.length, 1);
    });

    test('offset 超出段长时仍落在该段', () {
      const markers = [
        ScriptMarker(
          id: 'm2',
          scriptId: 's',
          sectionId: 'a',
          charOffset: 99,
          kind: MarkerKind.pause,
        ),
      ];
      final mapped = mapMarkersToLines(
        sections: sections,
        markers: markers,
        lines: lines,
      );
      expect(mapped[0]?.single.kind, MarkerKind.pause);
    });

    test('连续文本渲染后，全文偏移标记落到对应语义行', () {
      final rawLines = ScriptModel.parse(
        id: 's',
        title: 't',
        rawText: '第一段。\n\n第二段。',
      ).lines;
      // 合成 sectionId 与旧分段 id 不同，映射必须按顺序而不是 id。
      expect(rawLines[1].sectionId, isNot('b'));
      const markers = [
        ScriptMarker(
          id: 'm3',
          scriptId: 's',
          sectionId: 'b',
          // 全文偏移：第一段 4 字 + 空行 2 字 + 段内 2 字。
          charOffset: 8,
          kind: MarkerKind.emphasis,
        ),
      ];
      final mapped = mapMarkersToContinuousLines(
        rawText: '第一段。\n\n第二段。',
        markers: markers,
        lines: rawLines,
      );
      expect(mapped.keys, [1]);
      expect(mapped[1]?.single.charOffset, 2);
    });

    test('旧分段断点在连续文本行上按分段顺序定位', () {
      const twoSections = [
        ScriptSection(id: 'a', scriptId: 's', ord: 0, text: '第一句。第二句。'),
        ScriptSection(id: 'b', scriptId: 's', ord: 1, text: '第三句。'),
      ];
      final rawLines = ScriptModel.parse(
        id: 's',
        title: 't',
        rawText: '第一句。第二句。\n\n第三句。',
      ).lines;
      final mapped = mapLegacyAnchorToParagraphs(
        sections: twoSections,
        lines: rawLines,
        legacyAnchor: 2,
      );
      expect(mapped.line, 1);
      expect(mapped.charOffset, 0);
    });

    test('未知标记类型回退到自定义', () {
      expect(MarkerKind.parse('unknown'), MarkerKind.custom);
      expect(MarkerKind.parse('emphasis'), MarkerKind.emphasis);
    });
  });

  group('导入清洗', () {
    test('去页码与页眉脚', () {
      const raw = '标题\n\n第 3 页\n正文第一句。\n- 12 -\n正文第二句。';
      final cleaned = cleanImportedText(raw, const CleanOptions());
      expect(cleaned.contains('第 3 页'), isFalse);
      expect(cleaned.contains('- 12 -'), isFalse);
      expect(cleaned.contains('正文第一句。'), isTrue);
    });

    test('合并段内硬换行', () {
      const raw = '这是一句被\n折断的话。\n\n另一段。';
      final cleaned = cleanImportedText(
        raw,
        const CleanOptions(mergeHardLineBreaks: true),
      );
      expect(cleaned, '这是一句被折断的话。\n\n另一段。');
    });

    test('全角转半角', () {
      expect(normalizeWidth('ＡＢＣ１２３　全角'), 'ABC123 全角');
      expect(normalizeWidth('中文，标点：保留！'), '中文，标点：保留！');
    });

    test('Markdown 轻度清理', () {
      const raw = '# 标题\n\n**重点**内容\n- 列表项\n[链接](https://example.com)';
      final cleaned = cleanImportedText(
        raw,
        const CleanOptions(stripMarkdown: true),
      );
      expect(cleaned.contains('#'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('重点内容'), isTrue);
      expect(cleaned.contains('链接'), isTrue);
      expect(cleaned.contains('example.com'), isFalse);
    });

    test('默认标题取首个非空行', () {
      expect(suggestTitle('\n\n# 演讲标题\n正文'), '演讲标题');
      expect(suggestTitle('   \n'), '未命名台本');
    });
  });
}
