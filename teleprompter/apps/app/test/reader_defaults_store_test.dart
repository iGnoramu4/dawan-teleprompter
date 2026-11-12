import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/reader_settings/reader_defaults_store.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';

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

  test('未保存时返回 null', () async {
    expect(await loadGlobalReaderDefaults(repo), isNull);
  });

  test('保存后可加载，空字符串视为未保存', () async {
    await saveGlobalReaderDefaults(
      repo,
      const ReaderSettings(fontSize: 60, theme: ReaderTheme.stageWhite),
    );
    final loaded = await loadGlobalReaderDefaults(repo);
    expect(loaded?.fontSize, 60);
    expect(loaded?.theme, ReaderTheme.stageWhite);

    await repo.setSetting(readerDefaultsKey, '');
    expect(await loadGlobalReaderDefaults(repo), isNull);
  });

  test('坏数据回退 null 而不是抛异常', () async {
    await repo.setSetting(readerDefaultsKey, 'not-json');
    expect(await loadGlobalReaderDefaults(repo), isNull);

    await repo.setSetting(readerDefaultsKey, '[]');
    expect(await loadGlobalReaderDefaults(repo), isNull);
  });
}
