import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// 列表视图。
enum ScriptView { active, favorite, archived, trash }

/// 列表排序。
enum ScriptSort { updatedDesc, createdDesc, titleAsc, charCountDesc }

/// 列表项（避免列表页为每篇台本查一次库）。
class ScriptSummary {
  const ScriptSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.charCount,
    required this.sectionCount,
    required this.createdAt,
    required this.updatedAt,
    required this.lastViewedAt,
    required this.deletedAt,
    required this.favorite,
    required this.archived,
  });

  final String id;
  final String title;
  final String preview;
  final int charCount;
  final int sectionCount;
  final int createdAt;
  final int updatedAt;
  final int? lastViewedAt;
  final int? deletedAt;
  final bool favorite;
  final bool archived;

  bool get inTrash => deletedAt != null;
}

/// 编辑器提交的一个标记（偏移量是全文绝对位置）。
class EditableMarker {
  EditableMarker({
    required this.charOffset,
    required this.kind,
    this.label,
  });

  final int charOffset;
  final MarkerKind kind;
  final String? label;
}

/// 录制条目（§9.1 recordings）。
class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.scriptId,
    required this.path,
    required this.durationMs,
    required this.createdAt,
    required this.sizeBytes,
    this.sessionId,
    this.timelineJson,
  });

  final String id;
  final String scriptId;
  final String? sessionId;
  final String path;
  final int durationMs;
  final String? timelineJson;
  final int createdAt;
  final int sizeBytes;
}

/// 台本仓库（§9.1）：所有 SQL 细节都收敛在这里，UI 只面向领域模型。
class ScriptRepository {
  ScriptRepository(this.db);

  final AppDatabase db;

  static const Uuid _uuid = Uuid();
  static const String _seedSettingKey = 'seed_version';
  static const int seedVersion = 1;

  // ---------------------------------------------------------------- 列表

  /// 监听台本列表；搜索标题与正文，支持排序与视图过滤。
  Stream<List<ScriptSummary>> watchSummaries({
    String query = '',
    ScriptSort sort = ScriptSort.updatedDesc,
    ScriptView view = ScriptView.active,
  }) {
    final scripts$ = db.select(db.scripts).watch();
    final sections$ = db.select(db.sections).watch();
    return _combineLatest2(scripts$, sections$, (scriptRows, sectionRows) {
      final counts = <String, ({int sections, int chars})>{};
      for (final row in sectionRows) {
        final current = counts[row.scriptId] ?? (sections: 0, chars: 0);
        counts[row.scriptId] = (
          sections: current.sections + 1,
          chars: current.chars + row.charCount
        );
      }

      final keyword = query.trim().toLowerCase();
      final items = <ScriptSummary>[];
      for (final row in scriptRows) {
        if (!_inView(row, view)) continue;
        if (keyword.isNotEmpty &&
            !row.title.toLowerCase().contains(keyword) &&
            !row.rawText.toLowerCase().contains(keyword)) {
          continue;
        }
        final count = counts[row.id] ?? (sections: 0, chars: 0);
        items.add(
          ScriptSummary(
            id: row.id,
            title: row.title,
            preview: _preview(row.rawText, keyword),
            charCount: count.chars,
            sectionCount: count.sections,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            lastViewedAt: row.lastViewedAt,
            deletedAt: row.deletedAt,
            favorite: row.favorite,
            archived: row.archived,
          ),
        );
      }

      items.sort((a, b) => _compare(a, b, sort));
      return items;
    });
  }

  bool _inView(ScriptRow row, ScriptView view) {
    switch (view) {
      case ScriptView.active:
        return row.deletedAt == null && !row.archived;
      case ScriptView.favorite:
        return row.deletedAt == null && !row.archived && row.favorite;
      case ScriptView.archived:
        return row.deletedAt == null && row.archived;
      case ScriptView.trash:
        return row.deletedAt != null;
    }
  }

  int _compare(ScriptSummary a, ScriptSummary b, ScriptSort sort) {
    switch (sort) {
      case ScriptSort.updatedDesc:
        return b.updatedAt.compareTo(a.updatedAt);
      case ScriptSort.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case ScriptSort.titleAsc:
        return a.title.compareTo(b.title);
      case ScriptSort.charCountDesc:
        return b.charCount.compareTo(a.charCount);
    }
  }

  String _preview(String rawText, String keyword) {
    final flat = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return '';
    if (keyword.isNotEmpty) {
      final index = flat.toLowerCase().indexOf(keyword);
      if (index >= 0) {
        final start = index < 12 ? 0 : index - 12;
        final end = (start + 48).clamp(0, flat.length);
        return '${start > 0 ? '…' : ''}${flat.substring(start, end)}'
            '${end < flat.length ? '…' : ''}';
      }
    }
    return flat.length <= 60 ? flat : '${flat.substring(0, 60)}…';
  }

  // ---------------------------------------------------------------- 读取

  /// 整篇台本在存储层的固定 section id。
  ///
  /// 台本已取消段落结构：每篇只保留一行 section 承载全文。
  static String wholeSectionId(String scriptId) => 'whole:$scriptId';

  Future<ScriptDocument?> getDocument(String id) async {
    final row = await (db.select(db.scripts)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    final markerRows = await (db.select(db.markers)
          ..where((t) => t.scriptId.equals(id)))
        .get();

    final wholeId = wholeSectionId(id);
    return ScriptDocument(
      id: row.id,
      title: row.title,
      rawText: row.rawText,
      lang: row.lang,
      folderId: row.folderId,
      tags: _decodeTags(row.tags),
      favorite: row.favorite,
      archived: row.archived,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastViewedAt: row.lastViewedAt,
      sections: [
        ScriptSection(
          id: wholeId,
          scriptId: row.id,
          ord: 0,
          text: row.rawText,
        ),
      ],
      // 旧格式标记带有分段坐标，无法对应整篇连续文本，直接忽略。
      markers: [
        for (final marker in markerRows)
          if (marker.sectionId == wholeId)
            ScriptMarker(
              id: marker.id,
              scriptId: marker.scriptId,
              sectionId: wholeId,
              charOffset: marker.charOffset.clamp(0, row.rawText.length),
              kind: MarkerKind.parse(marker.kind),
              label: marker.label,
              color: marker.color,
            ),
      ],
    );
  }

  List<String> _decodeTags(String? tags) {
    if (tags == null || tags.isEmpty) return const [];
    try {
      final decoded = jsonDecode(tags);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } on FormatException {
      return const [];
    }
    return const [];
  }

  // ---------------------------------------------------------------- 写入

  /// 新建台本（导入/粘贴走同一条路径）：整篇作为连续文本保存。
  Future<ScriptDocument> createScript({
    String? title,
    required String text,
    String lang = 'zh',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final rawText = joinSections(splitIntoSections(text));
    final resolvedTitle =
        (title ?? '').trim().isNotEmpty ? title!.trim() : suggestTitle(rawText);

    await db.transaction(() async {
      await db.into(db.scripts).insert(
            ScriptsCompanion.insert(
              id: id,
              title: resolvedTitle,
              rawText: rawText,
              createdAt: now,
              updatedAt: now,
              lang: Value(lang),
            ),
          );
      await _writeWholeSection(id, rawText);
    });

    return (await getDocument(id))!;
  }

  /// 编辑器保存：整篇替换正文与标记，保留台本 id。
  Future<ScriptDocument> saveDocument({
    required String scriptId,
    required String title,
    required String text,
    required List<EditableMarker> markers,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await (db.delete(db.markers)..where((t) => t.scriptId.equals(scriptId)))
          .go();
      await (db.delete(db.sections)..where((t) => t.scriptId.equals(scriptId)))
          .go();
      await _writeWholeSection(scriptId, text);

      final wholeId = wholeSectionId(scriptId);
      for (final marker in markers) {
        await db.into(db.markers).insert(
              MarkersCompanion.insert(
                id: _uuid.v4(),
                scriptId: scriptId,
                sectionId: wholeId,
                charOffset: marker.charOffset.clamp(0, text.length),
                kind: marker.kind.key,
                label: Value((marker.label ?? '').trim().isEmpty
                    ? null
                    : marker.label!.trim()),
              ),
            );
      }

      await _updateScript(
        scriptId,
        ScriptsCompanion(
          title: Value(
            title.trim().isEmpty ? suggestTitle(text) : title.trim(),
          ),
          rawText: Value(text),
          updatedAt: Value(now),
        ),
      );
    });

    final document = await getDocument(scriptId);
    if (document == null) {
      throw StateError('台本不存在：$scriptId');
    }
    return document;
  }

  /// 写入承载整篇正文的唯一 section 行。
  Future<void> _writeWholeSection(String scriptId, String text) async {
    await db.into(db.sections).insert(
          SectionsCompanion.insert(
            id: wholeSectionId(scriptId),
            scriptId: scriptId,
            ord: 0,
            body: text,
            charCount: text.replaceAll(RegExp(r'\s'), '').length,
          ),
        );
  }

  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _updateScript(
      id,
      ScriptsCompanion(
        title: Value(trimmed),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setFavorite(String id, bool value) async {
    await _updateScript(id, ScriptsCompanion(favorite: Value(value)));
  }

  Future<void> setArchived(String id, bool value) async {
    await _updateScript(id, ScriptsCompanion(archived: Value(value)));
  }

  Future<void> softDelete(String id) async {
    await _updateScript(
      id,
      ScriptsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        archived: const Value(false),
      ),
    );
  }

  Future<void> restore(String id) async {
    await _updateScript(id, const ScriptsCompanion(deletedAt: Value(null)));
  }

  Future<void> _updateScript(String id, ScriptsCompanion companion) async {
    await (db.update(db.scripts)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<void> deleteForever(String id) async {
    await _deleteChildren([id]);
  }

  Future<void> _deleteChildren(Iterable<String> scriptIds) async {
    final ids = scriptIds.toList(growable: false);
    if (ids.isEmpty) return;
    final recordingPaths = <String>[];
    await db.transaction(() async {
      for (final id in ids) {
        final recordings = await (db.select(db.recordings)
              ..where((t) => t.scriptId.equals(id)))
            .get();
        recordingPaths.addAll(recordings.map((row) => row.path));
        await (db.delete(db.recordings)..where((t) => t.scriptId.equals(id)))
            .go();
        await (db.delete(db.markers)..where((t) => t.scriptId.equals(id))).go();
        await (db.delete(db.sections)..where((t) => t.scriptId.equals(id)))
            .go();
        await (db.delete(db.sessions)..where((t) => t.scriptId.equals(id)))
            .go();
        await (db.delete(db.scripts)..where((t) => t.id.equals(id))).go();
      }
    });
    await _deleteRecordingFiles(recordingPaths);
  }

  /// 回收站保留 30 天：清理过期项。
  Future<int> purgeExpiredTrash({int days = 30}) async {
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final expired = await (db.select(db.scripts)
          ..where((t) =>
              t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    await _deleteChildren(expired.map((row) => row.id));
    return expired.length;
  }

  Future<String> duplicate(String id) async {
    final document = await getDocument(id);
    if (document == null) throw StateError('台本不存在：$id');
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.scripts).insert(
            ScriptsCompanion.insert(
              id: newId,
              title: '${document.title}（副本）',
              rawText: document.rawText,
              createdAt: now,
              updatedAt: now,
              lang: Value(document.lang),
              favorite: Value(document.favorite),
            ),
          );

      final wholeId = wholeSectionId(newId);
      await db.into(db.sections).insert(
            SectionsCompanion.insert(
              id: wholeId,
              scriptId: newId,
              ord: 0,
              body: document.rawText,
              charCount: document.rawText.replaceAll(RegExp(r'\s'), '').length,
            ),
          );

      for (final marker in document.markers) {
        await db.into(db.markers).insert(
              MarkersCompanion.insert(
                id: _uuid.v4(),
                scriptId: newId,
                sectionId: wholeId,
                charOffset: marker.charOffset,
                kind: marker.kind.key,
                label: Value(marker.label),
                color: Value(marker.color),
              ),
            );
      }
    });

    return newId;
  }

  /// 导入 `.tps` 包中的一篇台本：重新分配 id，保留标记、收藏/归档与预设。
  ///
  /// 新格式每篇只有一个 section，正文即该 section 的全文。
  Future<ScriptDocument> importBundledScript(BundledScript bundled) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    // 新格式每篇只有一个 section；旧的多段包不再兼容。
    if (bundled.sections.length != 1 ||
        bundled.sections.single.text.trim().isEmpty) {
      throw const FormatException('台本格式已更新，请重新导入原始文档');
    }
    final rawText = bundled.sections.single.text;

    await db.transaction(() async {
      await db.into(db.scripts).insert(
            ScriptsCompanion.insert(
              id: id,
              title: bundled.title.trim().isEmpty
                  ? suggestTitle(rawText)
                  : bundled.title.trim(),
              rawText: rawText,
              createdAt: now,
              updatedAt: now,
              lang: Value(bundled.lang),
              tags: Value(
                bundled.tags.isEmpty ? null : jsonEncode(bundled.tags),
              ),
              favorite: Value(bundled.favorite),
              archived: Value(bundled.archived),
            ),
          );

      await _writeWholeSection(id, rawText);
      final wholeId = wholeSectionId(id);

      for (final marker in bundled.markers) {
        if (marker.section != 0) continue;
        final offset = marker.charOffset.clamp(0, rawText.length).toInt();
        await db.into(db.markers).insert(
              MarkersCompanion.insert(
                id: _uuid.v4(),
                scriptId: id,
                sectionId: wholeId,
                charOffset: offset,
                kind: marker.kind.key,
                label: Value(marker.label),
                color: Value(marker.color),
              ),
            );
      }
    });

    final preset = bundled.preset;
    if (preset != null) {
      await savePreset('script:$id', preset);
    }
    return (await getDocument(id))!;
  }

  /// 导出全部未删除台本（含归档、排除回收站）；无内容时返回 null。
  Future<ScriptBundle?> exportBundle() async {
    final rows =
        await (db.select(db.scripts)..where((t) => t.deletedAt.isNull())).get();
    final documents = <ScriptDocument>[];
    final presets = <String, Map<String, Object?>?>{};
    for (final row in rows) {
      final document = await getDocument(row.id);
      if (document == null) continue;
      documents.add(document);
      presets[document.id] = await loadPreset('script:${document.id}');
    }
    if (documents.isEmpty) return null;
    return ScriptBundle.fromDocuments(documents, presets: presets);
  }

  /// 整包导入，返回成功导入的篇数。
  ///
  /// 先整体校验再写库，避免遇到旧格式时留下导入了一半的状态。
  Future<int> importBundle(ScriptBundle bundle) async {
    if (bundle.scripts.any(
      (script) =>
          script.sections.length != 1 ||
          script.sections.single.text.trim().isEmpty,
    )) {
      throw const FormatException('台本格式已更新，请重新导入原始文档');
    }
    var imported = 0;
    for (final script in bundle.scripts) {
      await importBundledScript(script);
      imported++;
    }
    return imported;
  }

  Future<void> touchLastViewed(String id) async {
    await _updateScript(
      id,
      ScriptsCompanion(
        lastViewedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // ---------------------------------------------------------------- 断点

  /// 断点锚点所使用的语义行模型：1 = 旧版按句切行，2 = 段落化（0.22.0 起）。
  static String anchorModelKey(String scriptId) => 'anchor_model:$scriptId';

  /// 保存当前锚点（同一台本复用一个会话行，M1 断点续读）。
  ///
  /// [model] 记录写入锚点时使用的语义行模型，读取端据此决定是否需要迁移。
  Future<void> saveAnchor(String scriptId, int anchor, {int model = 2}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (db.select(db.sessions)
          ..where((t) => t.scriptId.equals(scriptId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .get();

    if (rows.isEmpty) {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: _uuid.v4(),
              scriptId: scriptId,
              startedAt: now,
              anchor: Value(anchor),
              endedAt: Value(now),
            ),
          );
    } else {
      await (db.update(db.sessions)..where((t) => t.id.equals(rows.first.id)))
          .write(
        SessionsCompanion(
          anchor: Value(anchor),
          endedAt: Value(now),
        ),
      );
    }
    await setSetting(anchorModelKey(scriptId), '$model');
  }

  Future<int?> lastAnchor(String scriptId) async {
    final rows = await (db.select(db.sessions)
          ..where((t) => t.scriptId.equals(scriptId) & t.anchor.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.anchor;
  }

  /// 读取断点锚点所属的语义行模型；0.21.x 及更早没有记录，按旧模型（1）处理。
  Future<int> lastAnchorModel(String scriptId) async {
    final value = await getSetting(anchorModelKey(scriptId));
    return int.tryParse(value ?? '') ?? 1;
  }

  // ---------------------------------------------------------------- 录制

  Future<void> insertRecording(RecordingEntry entry) async {
    await db.into(db.recordings).insert(
          RecordingsCompanion.insert(
            id: entry.id,
            scriptId: entry.scriptId,
            sessionId: Value(entry.sessionId),
            path: entry.path,
            durMs: entry.durationMs,
            timelineJson: Value(entry.timelineJson),
            createdAt: entry.createdAt,
            sizeBytes: entry.sizeBytes,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<List<RecordingEntry>> recordingsForScript(String scriptId) async {
    final rows = await (db.select(db.recordings)
          ..where((t) => t.scriptId.equals(scriptId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toRecordingEntry).toList(growable: false);
  }

  Future<RecordingEntry?> latestRecording(String scriptId) async {
    final rows = await (db.select(db.recordings)
          ..where((t) => t.scriptId.equals(scriptId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : _toRecordingEntry(rows.first);
  }

  /// 删除单条录制（数据库 + 音频文件）。
  Future<RecordingEntry?> deleteRecording(String id) async {
    final rows =
        await (db.select(db.recordings)..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return null;
    final entry = _toRecordingEntry(rows.first);
    await (db.delete(db.recordings)..where((t) => t.id.equals(id))).go();
    await _deleteRecordingFiles([entry.path]);
    return entry;
  }

  RecordingEntry _toRecordingEntry(RecordingRow row) => RecordingEntry(
        id: row.id,
        scriptId: row.scriptId,
        sessionId: row.sessionId,
        path: row.path,
        durationMs: row.durMs,
        timelineJson: row.timelineJson,
        createdAt: row.createdAt,
        sizeBytes: row.sizeBytes,
      );

  Future<void> _deleteRecordingFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // 文件已被移动/删除时忽略，不阻断数据库清理。
      }
    }
  }

  // ---------------------------------------------------------------- 预设

  Future<void> savePreset(
    String name,
    Map<String, Object?> json, {
    bool isDefault = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      if (isDefault) {
        await (db.update(db.presets)..where((t) => t.isDefault.equals(true)))
            .write(const PresetsCompanion(isDefault: Value(false)));
      }
      final existing = await (db.select(db.presets)
            ..where((t) => t.name.equals(name))
            ..limit(1))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.presets).insert(
              PresetsCompanion.insert(
                id: _uuid.v4(),
                name: name,
                json: jsonEncode(json),
                isDefault: Value(isDefault),
                updatedAt: now,
              ),
            );
      } else {
        await (db.update(db.presets)..where((t) => t.id.equals(existing.id)))
            .write(
          PresetsCompanion(
            json: Value(jsonEncode(json)),
            isDefault: Value(isDefault),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<Map<String, Object?>?> loadDefaultPreset() async {
    final row = await (db.select(db.presets)
          ..where((t) => t.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return _decodePreset(row?.json);
  }

  Future<Map<String, Object?>?> loadPreset(String name) async {
    final row = await (db.select(db.presets)
          ..where((t) => t.name.equals(name))
          ..limit(1))
        .getSingleOrNull();
    return _decodePreset(row?.json);
  }

  Map<String, Object?>? _decodePreset(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      return null;
    }
    return null;
  }

  // ---------------------------------------------------------------- 设置

  Future<void> setSetting(String key, String value) async {
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<String?> getSetting(String key) async {
    final row = await (db.select(db.appSettings)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  // ---------------------------------------------------------------- 首启播种

  /// 首次启动把内置台本写入数据库；已播种过则跳过。
  Future<int> seedIfNeeded(
      Iterable<({String title, String text})> seeds) async {
    final current = await getSetting(_seedSettingKey);
    if (current != null && int.tryParse(current) != null) return 0;

    var count = 0;
    for (final seed in seeds) {
      await createScript(title: seed.title, text: seed.text);
      count++;
    }
    await setSetting(_seedSettingKey, '$seedVersion');
    return count;
  }

  Future<int> activeCount() async {
    final rows = await (db.select(db.scripts)
          ..where((t) => t.deletedAt.isNull() & t.archived.equals(false)))
        .get();
    return rows.length;
  }
}

/// 两个 drift 流合成一个（避免为列表引入 rxdart）。
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A first, B second) combine,
) {
  late A latestA;
  late B latestB;
  var hasA = false;
  var hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  final controller = StreamController<R>();
  void emit() {
    if (hasA && hasB && controller.hasListener && !controller.isClosed) {
      controller.add(combine(latestA, latestB));
    }
  }

  controller.onListen = () {
    subA = first.listen(
      (value) {
        latestA = value;
        hasA = true;
        emit();
      },
      onError: controller.addError,
    );
    subB = second.listen(
      (value) {
        latestB = value;
        hasB = true;
        emit();
      },
      onError: controller.addError,
    );
  };
  controller.onCancel = () async {
    await subA?.cancel();
    await subB?.cancel();
  };
  return controller.stream;
}
