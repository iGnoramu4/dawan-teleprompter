/// 台本领域模型：分段、标记与整篇文档（§9.1 表结构的纯 Dart 映射）。
///
/// 该层只描述数据形状与分段规则，不依赖 Flutter，也不依赖存储实现。
library;

/// 标记类型（§4.2 M-04）。展示文案由 UI 层本地化。
enum MarkerKind {
  /// 重点强调。
  emphasis,

  /// 需要停顿。
  pause,

  /// 换气提示。
  breath,

  /// 舞台动作提示。
  action,

  /// 时间码。
  time,

  /// 自定义标记。
  custom;

  /// 存储/协议里的字符串值（与 `markers.kind` 一致）。
  String get key => name;

  /// 从存储值解析；未知值回退为 [MarkerKind.custom]。
  static MarkerKind parse(String value) {
    for (final kind in MarkerKind.values) {
      if (kind.name == value) return kind;
    }
    return MarkerKind.custom;
  }
}

/// 一个提词分段：编辑与跳段的最小单位。
class ScriptSection {
  /// 创建一个分段。
  const ScriptSection({
    required this.id,
    required this.scriptId,
    required this.ord,
    required this.text,
    this.note,
  });

  /// 分段 id（内部 UUID）。
  final String id;

  /// 所属台本 id。
  final String scriptId;

  /// 段落在台本内的顺序，从 0 开始。
  final int ord;

  /// 分段正文。
  final String text;

  /// 分段备注（提词时默认不显示）。
  final String? note;

  /// 正文字符数（不计空白，与列表页统计口径一致）。
  int get charCount => text.replaceAll(RegExp(r'\s'), '').length;

  /// 复制并按需替换字段。
  ScriptSection copyWith({
    String? id,
    String? scriptId,
    int? ord,
    String? text,
    String? note,
  }) {
    return ScriptSection(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      ord: ord ?? this.ord,
      text: text ?? this.text,
      note: note ?? this.note,
    );
  }

  @override
  String toString() => 'ScriptSection($ord: ${text.length} 字)';
}

/// 标记：落在某段内的字符偏移（offset 相对段首，§4.2 M-04）。
class ScriptMarker {
  /// 创建一个标记。
  const ScriptMarker({
    required this.id,
    required this.scriptId,
    required this.sectionId,
    required this.charOffset,
    required this.kind,
    this.label,
    this.color,
  });

  /// 标记 id。
  final String id;

  /// 所属台本 id。
  final String scriptId;

  /// 所属分段 id。
  final String sectionId;

  /// 字符偏移，0 表示段首。
  final int charOffset;

  /// 标记类型。
  final MarkerKind kind;

  /// 自定义备注。
  final String? label;

  /// 可选颜色值（ARGB）。
  final int? color;

  @override
  String toString() => 'ScriptMarker(${kind.key}@$charOffset)';
}

/// 一篇完整的台本（含分段与标记）。
class ScriptDocument {
  /// 创建一篇台本。
  const ScriptDocument({
    required this.id,
    required this.title,
    required this.rawText,
    required this.sections,
    required this.markers,
    this.lang = 'zh',
    this.folderId,
    this.tags = const [],
    this.favorite = false,
    this.archived = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastViewedAt,
  });

  /// 台本 id。
  final String id;

  /// 台本标题。
  final String title;

  /// 原始正文（编辑与导入的单一事实来源）。
  final String rawText;

  /// 语言标记。
  final String lang;

  /// 所属文件夹（可选）。
  final String? folderId;

  /// 标签列表。
  final List<String> tags;

  /// 是否收藏。
  final bool favorite;

  /// 是否归档。
  final bool archived;

  /// 非空表示在回收站中（毫秒时间戳）。
  final int? deletedAt;

  /// 创建时间（毫秒时间戳）。
  final int createdAt;

  /// 更新时间（毫秒时间戳）。
  final int updatedAt;

  /// 上次阅读时间（毫秒时间戳）。
  final int? lastViewedAt;

  /// 分段列表。
  final List<ScriptSection> sections;

  /// 标记列表。
  final List<ScriptMarker> markers;

  /// 全文字符数。
  int get charCount => sections.fold(0, (sum, s) => sum + s.charCount);

  /// 复制并按需替换字段；[clearDeletedAt] 为 true 时清空回收站时间。
  ScriptDocument copyWith({
    String? title,
    String? rawText,
    List<ScriptSection>? sections,
    List<ScriptMarker>? markers,
    bool? favorite,
    bool? archived,
    int? deletedAt,
    bool clearDeletedAt = false,
    int? updatedAt,
    int? lastViewedAt,
  }) {
    return ScriptDocument(
      id: id,
      title: title ?? this.title,
      rawText: rawText ?? this.rawText,
      lang: lang,
      folderId: folderId,
      tags: tags,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      sections: sections ?? this.sections,
      markers: markers ?? this.markers,
    );
  }

  @override
  String toString() => 'ScriptDocument($id, $title, ${sections.length} 段)';
}
