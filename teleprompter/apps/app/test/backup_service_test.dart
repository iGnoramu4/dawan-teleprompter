import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/backup_service.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late ScriptRepository repo;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tp-backup-test');
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('每日备份只写一次，内容可还原', () async {
    await repo.createScript(title: '备份稿', text: '第一段。\n\n第二段。');
    final now = DateTime(2026, 11, 6, 8);
    final service = BackupService(repo, root: root, clock: () => now);

    final first = await service.backupIfDue();
    expect(first, isNotNull);
    expect(first!.name, 'teleprompter-20261106.tps');
    expect(await service.backupIfDue(), isNull);

    final bundle = ScriptBundle.decode(await first.file.readAsString());
    expect(bundle.scriptCount, 1);
    expect(bundle.scripts.single.sections.length, 1);
  });

  test('保留最近 keep 份，旧备份被清理', () async {
    await repo.createScript(title: '备份稿', text: '内容。');
    var now = DateTime(2026, 11, 1, 8);
    final service = BackupService(repo, root: root, keep: 2, clock: () => now);
    for (var day = 1; day <= 4; day++) {
      now = DateTime(2026, 11, day, 8);
      await service.backupNow();
    }
    final items = await service.list();
    expect(items, hasLength(2));
    expect(items.first.name, 'teleprompter-20261104.tps');
    expect(items.last.name, 'teleprompter-20261103.tps');
  });

  test('没有台本时不备份', () async {
    final service = BackupService(repo, root: root);
    expect(await service.backupNow(), isNull);
    expect(await service.list(), isEmpty);
    expect(await service.latest(), isNull);
  });

  test('latest 返回最新备份并暴露路径与文件名', () async {
    await repo.createScript(title: '备份稿', text: '内容。');
    final service = BackupService(
      repo,
      root: root,
      clock: () => DateTime(2026, 11, 6, 8),
    );
    final created = await service.backupNow();
    expect(created, isNotNull);

    final latest = await service.latest();
    expect(latest, isNotNull);
    expect(latest!.name, 'teleprompter-20261106.tps');
    expect(latest.path, latest.file.path);
    expect(latest.file.existsSync(), isTrue);
  });
}
