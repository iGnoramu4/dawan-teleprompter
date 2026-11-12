import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/appearance_settings.dart';

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

  test('默认跟随系统与靛蓝', () async {
    final settings = await loadAppearanceSettings(repo);
    expect(settings.mode, ThemeMode.system);
    expect(settings.accent, TpAccent.indigo);
  });

  test('保存后可还原主题模式与强调色', () async {
    await saveAppearanceSettings(
      repo,
      const AppearanceSettings(mode: ThemeMode.dark, accent: TpAccent.teal),
    );
    final loaded = await loadAppearanceSettings(repo);
    expect(loaded.mode, ThemeMode.dark);
    expect(loaded.accent, TpAccent.teal);
  });

  test('坏数据与未知强调色回退默认', () async {
    await repo.setSetting(appearanceStorageKey, 'not-json');
    expect(
      (await loadAppearanceSettings(repo)).mode,
      ThemeMode.system,
    );

    final parsed = AppearanceSettings.fromRaw(
      '{"mode":"dark","accent":"unknown"}',
    );
    expect(parsed.mode, ThemeMode.dark);
    expect(parsed.accent, TpAccent.indigo);

    final fallback = AppearanceSettings.fromRaw('[]');
    expect(fallback.mode, ThemeMode.system);
    expect(fallback.accent, TpAccent.indigo);
  });

  test('copyWith 只替换传入字段', () {
    const base = AppearanceSettings();
    final copy = base.copyWith(mode: ThemeMode.light, accent: TpAccent.rose);
    expect(copy.mode, ThemeMode.light);
    expect(copy.accent, TpAccent.rose);
    expect(base.copyWith().mode, base.mode);
    expect(base.copyWith().accent, base.accent);
  });
}
