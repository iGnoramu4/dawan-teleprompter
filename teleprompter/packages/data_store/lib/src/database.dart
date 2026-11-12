import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// 台本（§9.1 scripts）。
@DataClassName('ScriptRow')
class Scripts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get rawText => text()();
  TextColumn get lang => text().withDefault(const Constant('zh'))();
  TextColumn get folderId => text().nullable()();
  TextColumn get tags => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastViewedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 分段（§9.1 sections）。
///
/// 外键由 repository 维护（drift_dev 2.35 的 `.references()` 列解析在
/// Dart 3.13 analyzer 下会抛类型错误，故改用显式级联删除）。
@DataClassName('SectionRow')
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get scriptId => text()();
  IntColumn get ord => integer()();

  /// Dart 端命名为 body，SQL 列名保持 `text`（避免与 drift 的 text() 构造器同名）。
  TextColumn get body => text().named('text')();
  TextColumn get note => text().nullable()();
  IntColumn get charCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 标记（§9.1 markers）。
@DataClassName('MarkerRow')
class Markers extends Table {
  TextColumn get id => text()();
  TextColumn get scriptId => text()();
  TextColumn get sectionId => text()();
  IntColumn get charOffset => integer()();
  TextColumn get kind => text()();
  TextColumn get label => text().nullable()();
  IntColumn get color => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 排版/滚动预设（§9.1 presets）。
@DataClassName('PresetRow')
class Presets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 阅读会话与断点（§9.1 sessions）。
@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get scriptId => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  IntColumn get anchor => integer().nullable()();
  TextColumn get statsJson => text().nullable()();
  TextColumn get settingsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 录制（§9.1 recordings）：音频文件 + 时间轴 + 元数据。
@DataClassName('RecordingRow')
class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get scriptId => text()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get path => text()();
  IntColumn get durMs => integer()();
  TextColumn get timelineJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get sizeBytes => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 设置键值（§9.1 app_settings）。
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Scripts,
    Sections,
    Markers,
    Presets,
    Sessions,
    Recordings,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 测试与工具使用：内存库。
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// 打开磁盘库（后台 isolate 执行 SQL）。
  static AppDatabase openFile(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sections_script '
            'ON sections(script_id, ord)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_scripts_updated '
            'ON scripts(updated_at DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sessions_script '
            'ON sessions(script_id, started_at DESC)',
          );
          await _createRecordingIndex();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(recordings);
            await _createRecordingIndex();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createRecordingIndex() => customStatement(
        'CREATE INDEX IF NOT EXISTS idx_recordings_script '
        'ON recordings(script_id, created_at DESC)',
      );
}
