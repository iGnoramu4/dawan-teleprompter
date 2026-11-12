import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late ScriptRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('新建台本以整篇连续文本写入原文', () async {
    final document = await repo.createScript(
      title: '测试稿',
      text: '第一段第一句。第一段第二句。\n\n第二段。',
    );

    expect(document.title, '测试稿');
    expect(document.sections.length, 1);
    expect(document.sections.single.text, document.rawText);
    expect(document.charCount,
        document.rawText.replaceAll(RegExp(r'\s'), '').length);
    expect(document.markers, isEmpty);

    final loaded = await repo.getDocument(document.id);
    expect(loaded, isNotNull);
    expect(loaded!.sections.map((s) => s.ord), [0]);
    expect(loaded.sections.single.text, loaded.rawText);
  });

  test('标题为空时用正文首行', () async {
    final document = await repo.createScript(text: '演讲标题\n\n正文内容。');
    expect(document.title, '演讲标题');
  });

  test('导入 .tps 合并为整篇正文并保留标记、收藏与预设', () async {
    final source = await repo.createScript(title: '原稿', text: '第一段。\n\n第二段。');
    await repo.savePreset('script:${source.id}', {'fontSize': 48});
    final bundle = ScriptBundle.fromDocuments(
      [source.copyWith(favorite: true)],
      presets: {
        source.id: await repo.loadPreset('script:${source.id}'),
      },
    );
    final bundled = ScriptBundle.decode(bundle.encode()).scripts.single;

    final imported = await repo.importBundledScript(bundled);

    expect(imported.id, isNot(source.id));
    expect(imported.title, '原稿');
    expect(imported.favorite, isTrue);
    expect(imported.sections.length, 1);
    expect(imported.rawText, source.rawText);
    expect(await repo.loadPreset('script:${imported.id}'), {'fontSize': 48});
  });

  test('整包导出包含归档、排除回收站，并可整包导入', () async {
    final active = await repo.createScript(title: '在用', text: '第一段。\n\n第二段。');
    final archived = await repo.createScript(title: '归档', text: '归档内容。');
    await repo.setArchived(archived.id, true);
    final trashed = await repo.createScript(title: '回收站', text: '待删内容。');
    await repo.softDelete(trashed.id);
    await repo.savePreset('script:${active.id}', {'fontSize': 40});

    final bundle = await repo.exportBundle();
    expect(bundle, isNotNull);
    expect(bundle!.scriptCount, 2);
    final titles = bundle.scripts.map((s) => s.title).toSet();
    expect(titles, containsAll(['在用', '归档']));
    expect(titles, isNot(contains('回收站')));

    final decoded = ScriptBundle.decode(bundle.encode());
    final imported = await repo.importBundle(decoded);
    expect(imported, 2);

    final importedDocs = (await repo
            .watchSummaries(
              view: ScriptView.archived,
              sort: ScriptSort.titleAsc,
            )
            .first)
        .where((s) => s.title == '归档')
        .toList();
    expect(importedDocs.length, 2);
  });

  test('列表搜索、排序与视图过滤', () async {
    final a = await repo.createScript(title: '苹果', text: '苹果内容。');
    final b = await repo.createScript(title: '香蕉', text: '香蕉内容。');
    await repo.setFavorite(b.id, true);
    await repo.setArchived(a.id, true);

    final active = await repo.watchSummaries().first;
    expect(active.map((s) => s.id), isNot(contains(a.id)));

    final favorites =
        await repo.watchSummaries(view: ScriptView.favorite).first;
    expect(favorites.single.id, b.id);

    final archived = await repo.watchSummaries(view: ScriptView.archived).first;
    expect(archived.single.id, a.id);

    final searched = await repo.watchSummaries(query: '香蕉').first;
    expect(searched.map((s) => s.id), contains(b.id));
    expect(searched.map((s) => s.id), isNot(contains(a.id)));

    final byTitle = await repo
        .watchSummaries(sort: ScriptSort.titleAsc, view: ScriptView.archived)
        .first;
    expect(byTitle.single.title, '苹果');
  });

  test('回收站：软删除、恢复、彻底删除', () async {
    final document = await repo.createScript(title: '待删', text: '内容。');

    await repo.softDelete(document.id);
    final trash = await repo.watchSummaries(view: ScriptView.trash).first;
    expect(trash.single.id, document.id);

    await repo.restore(document.id);
    expect(await repo.watchSummaries(view: ScriptView.trash).first, isEmpty);

    await repo.softDelete(document.id);
    await repo.deleteForever(document.id);
    expect(await repo.getDocument(document.id), isNull);
  });

  test('编辑器保存：分段替换、标记落盘、顺序正确', () async {
    final document = await repo.createScript(
      title: '标记稿',
      text: '第一段。第二段。',
    );

    final saved = await repo.saveDocument(
      scriptId: document.id,
      title: '标记稿（改）',
      text: '第一段。第二段。\n\n第三段。',
      markers: [
        EditableMarker(
          charOffset: 4,
          kind: MarkerKind.emphasis,
          label: '重音',
        ),
      ],
    );

    expect(saved.title, '标记稿（改）');
    expect(saved.sections.single.text, saved.rawText);
    expect(saved.sections.length, 1);
    expect(saved.markers.single.charOffset, 4);
    expect(saved.markers.single.kind, MarkerKind.emphasis);
    expect(saved.rawText, '第一段。第二段。\n\n第三段。');

    final model = ScriptModel.parse(
      id: saved.id,
      title: saved.title,
      rawText: saved.rawText,
    );
    final markerLines = mapMarkersToContinuousLines(
      rawText: saved.rawText,
      markers: saved.markers,
      lines: model.lines,
    );
    expect(markerLines.keys.single, 0);
  });

  test('复制台本保留整篇正文与标记', () async {
    final document = await repo.createScript(title: '原稿', text: '内容。');
    await repo.saveDocument(
      scriptId: document.id,
      title: '原稿',
      text: '内容。',
      markers: [
        EditableMarker(
          charOffset: 1,
          kind: MarkerKind.pause,
        ),
      ],
    );

    final copyId = await repo.duplicate(document.id);
    final copy = await repo.getDocument(copyId);
    expect(copy!.title, '原稿（副本）');
    expect(copy.sections.length, 1);
    expect(copy.markers.length, 1);
    expect(copy.markers.single.sectionId, copy.sections.single.id);
  });

  test('断点：保存与读取最近锚点', () async {
    final document = await repo.createScript(title: '断点稿', text: '内容。');
    await repo.saveAnchor(document.id, 12);
    expect(await repo.lastAnchor(document.id), 12);
    expect(await repo.lastAnchorModel(document.id), 2);
    await repo.saveAnchor(document.id, 30, model: 1);
    expect(await repo.lastAnchor(document.id), 30);
    expect(await repo.lastAnchorModel(document.id), 1);
  });

  test('断点：旧数据没有模型记录时按旧版锚点处理', () async {
    final document = await repo.createScript(title: '旧断点', text: '内容。');
    expect(await repo.lastAnchorModel(document.id), 1);
  });

  test('预设：默认预设唯一并可读取', () async {
    await repo.savePreset('舞台', {'fontSize': 64}, isDefault: true);
    await repo.savePreset('近距', {'fontSize': 32}, isDefault: true);

    final defaultPreset = await repo.loadDefaultPreset();
    expect(defaultPreset?['fontSize'], 32);
    expect((await repo.loadPreset('舞台'))?['fontSize'], 64);
  });

  test('设置：读写与首启播种幂等', () async {
    await repo.setSetting('theme', 'dark');
    expect(await repo.getSetting('theme'), 'dark');

    final first = await repo.seedIfNeeded([
      (title: '内置一', text: '内容一。'),
      (title: '内置二', text: '内容二。'),
    ]);
    expect(first, 2);
    final second = await repo.seedIfNeeded([
      (title: '内置一', text: '内容一。'),
    ]);
    expect(second, 0);
    expect(await repo.activeCount(), 2);
  });

  group('录制（schema v2）', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tps-rec-');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('写入后可按台本读取，最近的在前', () async {
      final script = await repo.createScript(title: '录制稿', text: '内容。');
      final first = File('${tempDir.path}/a.wav')..writeAsStringSync('a');
      final second = File('${tempDir.path}/b.wav')..writeAsStringSync('bb');

      await repo.insertRecording(
        RecordingEntry(
          id: 'r1',
          scriptId: script.id,
          path: first.path,
          durationMs: 1000,
          createdAt: 100,
          sizeBytes: 1,
          timelineJson: '{"version":1}',
        ),
      );
      await repo.insertRecording(
        RecordingEntry(
          id: 'r2',
          scriptId: script.id,
          path: second.path,
          durationMs: 2000,
          createdAt: 200,
          sizeBytes: 2,
        ),
      );

      final list = await repo.recordingsForScript(script.id);
      expect(list.map((entry) => entry.id), ['r2', 'r1']);
      expect((await repo.latestRecording(script.id))?.id, 'r2');
      expect(list.first.timelineJson, isNull);
      expect(list.last.timelineJson, '{"version":1}');
      expect(await repo.recordingsForScript('missing'), isEmpty);
    });

    test('删除单条录制同时删除音频文件', () async {
      final script = await repo.createScript(title: '删除稿', text: '内容。');
      final audio = File('${tempDir.path}/c.wav')..writeAsStringSync('c');
      await repo.insertRecording(
        RecordingEntry(
          id: 'r3',
          scriptId: script.id,
          path: audio.path,
          durationMs: 500,
          createdAt: 1,
          sizeBytes: 1,
        ),
      );

      final removed = await repo.deleteRecording('r3');
      expect(removed?.path, audio.path);
      expect(await audio.exists(), isFalse);
      expect(await repo.recordingsForScript(script.id), isEmpty);
      expect(await repo.deleteRecording('r3'), isNull);
    });

    test('永久删除台本级联删除录制与文件', () async {
      final script = await repo.createScript(title: '级联稿', text: '内容。');
      final audio = File('${tempDir.path}/d.wav')..writeAsStringSync('d');
      await repo.insertRecording(
        RecordingEntry(
          id: 'r4',
          scriptId: script.id,
          path: audio.path,
          durationMs: 500,
          createdAt: 1,
          sizeBytes: 1,
        ),
      );

      await repo.deleteForever(script.id);
      expect(await audio.exists(), isFalse);
      expect(await repo.recordingsForScript(script.id), isEmpty);
    });
  });
}
