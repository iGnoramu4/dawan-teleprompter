/// `.tps` 台本包：导入/导出与备份的稳定 JSON 格式。
///
/// 只描述数据形状与校验，不触碰文件系统与 Flutter。
library;

import 'dart:convert';

import 'script_document.dart';
import 'script_model.dart';
import 'text_cleaner.dart';

/// 包格式标识与版本。
abstract final class ScriptBundleFormat {
  /// 文件扩展名（不含点）。
  static const String extension = 'tps';

  /// 根字段 `format` 的固定值。
  static const String key = 'tps';

  /// 当前写入版本。
  static const int version = 1;

  const ScriptBundleFormat._();
}

/// 包内的一条分段。
class BundledSection {
  /// 创建分段。
  const BundledSection({required this.text, this.note});

  /// 分段正文。
  final String text;

  /// 分段备注（可为空）。
  final String? note;

  /// 转为 JSON。
  Map<String, Object?> toJson() => {
        'text': text,
        if (note != null) 'note': note,
      };
}

/// 包内的一条标记；`section` 为分包内分段下标（从 0 开始）。
class BundledMarker {
  /// 创建标记。
  const BundledMarker({
    required this.section,
    required this.charOffset,
    required this.kind,
    this.label,
    this.color,
  });

  /// 所属分段下标。
  final int section;

  /// 段内字符偏移。
  final int charOffset;

  /// 标记类型。
  final MarkerKind kind;

  /// 标记文字（可为空）。
  final String? label;

  /// 颜色值（ARGB，可为空）。
  final int? color;

  /// 转为 JSON。
  Map<String, Object?> toJson() => {
        'section': section,
        'offset': charOffset,
        'kind': kind.key,
        if (label != null) 'label': label,
        if (color != null) 'color': color,
      };
}

/// 包内的一篇台本（不含内部 id；导入时重新分配）。
class BundledScript {
  /// 创建台本节点。
  const BundledScript({
    required this.title,
    required this.rawText,
    required this.sections,
    this.markers = const [],
    this.lang = 'zh',
    this.tags = const [],
    this.favorite = false,
    this.archived = false,
    this.preset,
  });

  /// 台本标题。
  final String title;

  /// 原始正文。
  final String rawText;

  /// 语言标签。
  final String lang;

  /// 标签列表。
  final List<String> tags;

  /// 是否收藏。
  final bool favorite;

  /// 是否归档。
  final bool archived;

  /// 分段列表。
  final List<BundledSection> sections;

  /// 标记列表。
  final List<BundledMarker> markers;

  /// 阅读预设（可为空）。
  final Map<String, Object?>? preset;

  /// 转为 JSON。
  Map<String, Object?> toJson() => {
        'title': title,
        'lang': lang,
        'rawText': rawText,
        'tags': tags,
        'favorite': favorite,
        'archived': archived,
        'sections': [for (final section in sections) section.toJson()],
        'markers': [for (final marker in markers) marker.toJson()],
        if (preset != null) 'preset': preset,
      };
}

/// 一个 `.tps` 文件的内容。
class ScriptBundle {
  /// 创建包。
  const ScriptBundle({required this.exportedAt, required this.scripts});

  /// 导出时间。
  final DateTime exportedAt;

  /// 包内台本。
  final List<BundledScript> scripts;

  /// 包内台本数量。
  int get scriptCount => scripts.length;

  /// 从台本与可选预设构建包；预设键为台本 id。
  factory ScriptBundle.fromDocuments(
    Iterable<ScriptDocument> documents, {
    Map<String, Map<String, Object?>?> presets = const {},
    DateTime? exportedAt,
  }) {
    final list = documents.toList(growable: false);
    if (list.isEmpty) {
      throw const FormatException('导出内容为空');
    }
    return ScriptBundle(
      exportedAt: exportedAt ?? DateTime.now(),
      scripts: [
        for (final document in list)
          BundledScript(
            title: document.title,
            rawText: document.rawText,
            lang: document.lang,
            tags: document.tags,
            favorite: document.favorite,
            archived: document.archived,
            sections: [
              for (final section in document.sections)
                BundledSection(text: section.text, note: section.note),
            ],
            markers: [
              for (final marker in document.markers)
                BundledMarker(
                  section: _sectionIndex(document.sections, marker.sectionId),
                  charOffset: marker.charOffset,
                  kind: marker.kind,
                  label: marker.label,
                  color: marker.color,
                ),
            ].where((marker) => marker.section >= 0).toList(growable: false),
            preset: presets[document.id],
          ),
      ],
    );
  }

  /// 解析并校验 `.tps` 文本。
  factory ScriptBundle.decode(String source) {
    Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const FormatException('不是有效的 JSON');
    }
    if (root is! Map<String, Object?>) {
      throw const FormatException('根节点必须是对象');
    }
    if (root['format'] != ScriptBundleFormat.key) {
      throw const FormatException('不是 .tps 文件');
    }
    final version = root['version'];
    if (version is! int || version < 1) {
      throw const FormatException('缺少有效的 format 版本');
    }
    if (version > ScriptBundleFormat.version) {
      throw FormatException('不支持更高版本的 .tps（v$version）');
    }
    final scripts = root['scripts'];
    if (scripts is! List || scripts.isEmpty) {
      throw const FormatException('包内没有台本');
    }
    final exportedAt = DateTime.tryParse('${root['exportedAt'] ?? ''}');
    return ScriptBundle(
      exportedAt: exportedAt ?? DateTime.now(),
      scripts: [
        for (final raw in scripts) _parseScript(raw),
      ],
    );
  }

  /// 序列化为 JSON 文本（紧凑格式，便于备份与互传）。
  String encode() => jsonEncode({
        'format': ScriptBundleFormat.key,
        'version': ScriptBundleFormat.version,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'scripts': [for (final script in scripts) script.toJson()],
      });

  static int _sectionIndex(List<ScriptSection> sections, String id) {
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].id == id) return i;
    }
    return -1;
  }

  static BundledScript _parseScript(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('台本节点必须是对象');
    }
    final rawSections = raw['sections'];
    if (rawSections is! List || rawSections.isEmpty) {
      throw const FormatException('台本缺少分段');
    }
    final sections = <BundledSection>[];
    for (final item in rawSections) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('分段必须是对象');
      }
      final text = item['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const FormatException('分段正文为空');
      }
      final note = item['note'];
      sections.add(
        BundledSection(
          text: text,
          note: note is String && note.trim().isNotEmpty ? note.trim() : null,
        ),
      );
    }

    final markers = <BundledMarker>[];
    final rawMarkers = raw['markers'];
    if (rawMarkers is List) {
      for (final item in rawMarkers) {
        if (item is! Map<String, Object?>) {
          throw const FormatException('标记必须是对象');
        }
        final section = item['section'];
        final offset = item['offset'];
        if (section is! int ||
            section < 0 ||
            section >= sections.length ||
            offset is! int) {
          throw const FormatException('标记的分段或偏移不合法');
        }
        if (offset < 0 || offset > sections[section].text.length) {
          throw const FormatException('标记的字符偏移越界');
        }
        final label = item['label'];
        final color = item['color'];
        markers.add(
          BundledMarker(
            section: section,
            charOffset: offset,
            kind: MarkerKind.parse('${item['kind'] ?? ''}'),
            label: label is String && label.trim().isNotEmpty
                ? label.trim()
                : null,
            color: color is int ? color : null,
          ),
        );
      }
    }

    final title = raw['title'];
    final rawText = raw['rawText'];
    final resolvedRaw = rawText is String && rawText.trim().isNotEmpty
        ? rawText
        : joinSections(sections.map((section) => section.text));
    final tags = raw['tags'];
    final preset = raw['preset'];
    return BundledScript(
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : suggestTitle(resolvedRaw),
      rawText: resolvedRaw,
      lang: raw['lang'] is String ? raw['lang']! as String : 'zh',
      tags: tags is List
          ? tags.whereType<String>().toList(growable: false)
          : const [],
      favorite: raw['favorite'] is bool && raw['favorite']! as bool,
      archived: raw['archived'] is bool && raw['archived']! as bool,
      sections: sections,
      markers: markers,
      preset: preset is Map<String, Object?> ? preset : null,
    );
  }
}
