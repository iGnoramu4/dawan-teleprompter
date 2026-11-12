import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

ScriptDocument _document() => const ScriptDocument(
      id: 's1',
      title: '演示台本',
      rawText: '第一段。\n第二段。',
      sections: [
        ScriptSection(id: 'a', scriptId: 's1', ord: 0, text: '第一段。'),
        ScriptSection(
            id: 'b', scriptId: 's1', ord: 1, text: '第二段。', note: '备注'),
      ],
      markers: [
        ScriptMarker(
          id: 'm1',
          scriptId: 's1',
          sectionId: 'b',
          charOffset: 1,
          kind: MarkerKind.emphasis,
          label: '重音',
        ),
      ],
      createdAt: 1,
      updatedAt: 2,
    );

void main() {
  test('.tps 往返保留分段、备注、标记与预设', () {
    final bundle = ScriptBundle.fromDocuments(
      [_document()],
      presets: {
        's1': {'fontSize': 48, 'mirrorX': true},
      },
      exportedAt: DateTime.utc(2026, 11, 6),
    );
    final decoded = ScriptBundle.decode(bundle.encode());

    expect(decoded.scriptCount, 1);
    final script = decoded.scripts.single;
    expect(script.title, '演示台本');
    expect(script.sections.length, 2);
    expect(script.sections[1].note, '备注');
    expect(script.markers.single.section, 1);
    expect(script.markers.single.charOffset, 1);
    expect(script.markers.single.kind, MarkerKind.emphasis);
    expect(script.markers.single.label, '重音');
    expect(script.preset, {'fontSize': 48, 'mirrorX': true});
  });

  test('拒绝非 .tps 与未来版本', () {
    expect(
      () => ScriptBundle.decode('{"format":"other","version":1,"scripts":[]}'),
      throwsFormatException,
    );
    expect(
      () => ScriptBundle.decode('{"format":"tps","version":99,"scripts":[]}'),
      throwsFormatException,
    );
  });

  test('拒绝越界标记与空分段', () {
    const json = '{"format":"tps","version":1,"scripts":[{"title":"t",'
        '"sections":[{"text":"abc"}],"markers":[{"section":0,"offset":9,'
        '"kind":"pause"}]}]}';
    expect(() => ScriptBundle.decode(json), throwsFormatException);
    const empty = '{"format":"tps","version":1,"scripts":[{"title":"t",'
        '"sections":[{"text":"  "}]}]}';
    expect(() => ScriptBundle.decode(empty), throwsFormatException);
  });
}
