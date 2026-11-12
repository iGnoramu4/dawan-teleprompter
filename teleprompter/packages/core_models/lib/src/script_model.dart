/// 台本分段与断行规则：段落即语义行（§4.2 M-01）。
///
/// 从 0.22.0 起，正文只按空行切段：同一段内的文字连续排布，不再按句号、
/// 逗号等标点切成多条语义行；段内换行完全交给排版层按可用宽度自然折行。
/// [splitText] 仅保留给旧台本锚点迁移与预览等兼容场景。
///
/// 所有切分都保留原文标点，返回每段在原文中的字符 [start, end)，
/// 这样标记的 offset 与编辑后的 rawText 能保持一致。
library;

import 'script_document.dart';

/// 一段被切出来的原文片段。
class TextPiece {
  /// 用原文区间构造片段。
  const TextPiece({required this.text, required this.start, required this.end});

  /// 片段文本（已去除首尾空白）。
  final String text;

  /// 在原文中的起始下标。
  final int start;

  /// 在原文中的结束下标（不含）。
  final int end;
}

final RegExp _sentenceEnd = RegExp(r'[。！？!?；;]+');
final RegExp _softBreak = RegExp(r'[，,、：:]');
final RegExp _blankLine = RegExp(r'\n[ \t]*\n');

bool _isSpace(int code) =>
    code == 32 || code == 9 || code == 10 || code == 13 || code == 0x3000;

/// 把 `\r\n` / `\r` 统一为 `\n`。
String normalizeNewlines(String raw) =>
    raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// 把一段文本切成"行"：先按句末标点断句，超长再在逗号/顿号处切。
///
/// [maxChars] 是一次显示的行字数上限。
List<TextPiece> splitText(String source, int maxChars) {
  final result = <TextPiece>[];
  var segStart = 0;

  void flush(int segEnd) {
    var start = segStart;
    var end = segEnd;
    while (start < end && _isSpace(source.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isSpace(source.codeUnitAt(end - 1))) {
      end--;
    }
    if (end > start) {
      final text = source.substring(start, end);
      if (text.length <= maxChars) {
        result.add(TextPiece(text: text, start: start, end: end));
      } else {
        _splitLong(source, start, end, maxChars, result);
      }
    }
    segStart = segEnd;
  }

  for (final match in _sentenceEnd.allMatches(source)) {
    flush(match.end);
  }
  flush(source.length);
  return result;
}

void _splitLong(
  String source,
  int start,
  int end,
  int maxChars,
  List<TextPiece> out,
) {
  var cursor = start;
  while (end - cursor > maxChars) {
    final windowEnd = cursor + maxChars;
    var cut = -1;
    for (final match
        in _softBreak.allMatches(source.substring(cursor, windowEnd))) {
      cut = cursor + match.end;
    }
    if (cut <= cursor) cut = windowEnd;

    var a = cursor;
    var b = cut;
    while (a < b && _isSpace(source.codeUnitAt(a))) {
      a++;
    }
    while (b > a && _isSpace(source.codeUnitAt(b - 1))) {
      b--;
    }
    if (b > a) {
      out.add(TextPiece(text: source.substring(a, b), start: a, end: b));
    }
    cursor = cut;
  }

  var a = cursor;
  var b = end;
  while (a < b && _isSpace(source.codeUnitAt(a))) {
    a++;
  }
  while (b > a && _isSpace(source.codeUnitAt(b - 1))) {
    b--;
  }
  if (b > a) {
    out.add(TextPiece(text: source.substring(a, b), start: a, end: b));
  }
}

/// 把整篇原文切成段落（提词语义行的默认规则）。
///
/// 只按空行切分：段落内的句号、逗号、分号都不再产生新行。
/// 旧版按 120 字累计切分只保留在 [splitText] 中，供迁移旧锚点使用。
List<String> splitIntoSections(String rawText) {
  final normalized = normalizeNewlines(rawText);
  final sections = <String>[];
  for (final paragraph in normalized.split(_blankLine)) {
    final text = paragraph.trim();
    if (text.isNotEmpty) sections.add(text);
  }
  return sections;
}

/// 重新拼出台本原文（分段之间以空行分隔）。
String joinSections(Iterable<String> sections) => sections
    .map((text) => text.trim())
    .where((text) => text.isNotEmpty)
    .join('\n\n');

/// 标记 → 行号映射。
///
/// 一个标记只归属一行：取该段内起始偏移不超过标记偏移的最后一行。
/// 段落化后每段只有一条语义行，因此标记都会落到所属段落。
Map<int, List<ScriptMarker>> mapMarkersToLines({
  required List<ScriptSection> sections,
  required List<ScriptMarker> markers,
  required List<ScriptLine> lines,
}) {
  final linesBySection = <String, List<ScriptLine>>{};
  for (final line in lines) {
    final sectionId = line.sectionId;
    if (sectionId == null) continue;
    linesBySection.putIfAbsent(sectionId, () => []).add(line);
  }

  final result = <int, List<ScriptMarker>>{};
  for (final marker in markers) {
    final sectionLines = linesBySection[marker.sectionId];
    if (sectionLines == null || sectionLines.isEmpty) continue;

    var target = sectionLines.first;
    for (final line in sectionLines) {
      if (line.sectionCharStart <= marker.charOffset) {
        target = line;
      } else {
        break;
      }
    }
    result.putIfAbsent(target.index, () => []).add(marker);
  }
  return result;
}

/// 一条提词语义行。
///
/// 一条语义行 = 一个自然段（空行分隔）。段内不再按标点切行，
/// 视觉行由 `core_reader_layout` 的 `LayoutSnapshot` 按宽度折行生成。
class ScriptLine {
  /// 创建一行。
  const ScriptLine({
    required this.index,
    required this.text,
    this.sectionId,
    this.sectionCharStart = 0,
  });

  /// 行号（从 0 开始）。
  final int index;

  /// 行文本（完整段落）。
  final String text;

  /// 所属分段 id（从数据库台本渲染时非空）。
  final String? sectionId;

  /// 本行首个字符在该分段内的偏移，用于把标记落到行。
  ///
  /// 段落化后每段只有一条语义行，因此恒为 0；保留字段以兼容旧标记与
  /// 旧锚点迁移。
  final int sectionCharStart;

  @override
  String toString() => 'ScriptLine($index: $text)';
}

/// 一篇台本。
class ScriptModel {
  /// 创建台本模型。
  const ScriptModel({
    required this.id,
    required this.title,
    required this.rawText,
    required this.lines,
  });

  /// 台本 id。
  final String id;

  /// 台本标题。
  final String title;

  /// 原始正文。
  final String rawText;

  /// 断行后的提词行。
  final List<ScriptLine> lines;

  /// 全文字符数。
  int get charCount => lines.fold(0, (sum, line) => sum + line.text.length);

  /// 从数据库分段渲染：每个分段就是一条语义行（段落）。
  ///
  /// 旧版会再把每个分段按句末标点切成多条行；0.22.0 起不再切分，
  /// 段内折行由排版层按宽度完成。
  factory ScriptModel.fromSections({
    required String id,
    required String title,
    required String rawText,
    required List<ScriptSection> sections,
  }) {
    final ordered = [...sections]..sort((a, b) => a.ord.compareTo(b.ord));
    final lines = <ScriptLine>[
      for (var i = 0; i < ordered.length; i++)
        ScriptLine(
          index: i,
          text: ordered[i].text,
          sectionId: ordered[i].id,
          sectionCharStart: 0,
        ),
    ];
    return ScriptModel(
      id: id,
      title: title,
      rawText: rawText,
      lines: lines,
    );
  }

  /// 直接按原文分段（导入预览、测试与缓存构建使用）。
  factory ScriptModel.parse({
    required String id,
    required String title,
    required String rawText,
  }) {
    final sections = splitIntoSections(rawText);
    return ScriptModel.fromSections(
      id: id,
      title: title,
      rawText: rawText,
      sections: [
        for (var i = 0; i < sections.length; i++)
          ScriptSection(
            id: 'section-$i',
            scriptId: id,
            ord: i,
            text: sections[i],
          ),
      ],
    );
  }
}

/// 旧语义行锚点在段落模型中的位置。
class LegacyAnchorMapping {
  /// 创建映射结果。
  const LegacyAnchorMapping({required this.line, required this.charOffset});

  /// 段落模型中的语义行号。
  final int line;

  /// 段落内的字符偏移。
  final int charOffset;
}

/// 全文标记 → 连续文本语义行。
///
/// 台本取消段落结构后，标记的 `charOffset` 是全文绝对偏移；
/// 这里按 `rawText` 中每个段落的起点把标记落到对应语义行，
/// 偏移换算成行内偏移（越界夹到行尾）。
Map<int, List<ScriptMarker>> mapMarkersToContinuousLines({
  required String rawText,
  required List<ScriptMarker> markers,
  required List<ScriptLine> lines,
}) {
  final starts = <int>[];
  var cursor = 0;
  for (final line in lines) {
    var index = rawText.indexOf(line.text, cursor);
    if (index < 0) index = cursor.clamp(0, rawText.length);
    starts.add(index);
    cursor = index + line.text.length;
  }

  final result = <int, List<ScriptMarker>>{};
  for (final marker in markers) {
    if (lines.isEmpty) break;
    final global = marker.charOffset.clamp(0, rawText.length);
    var line = 0;
    for (var i = 0; i < lines.length; i++) {
      if (starts[i] <= global) {
        line = i;
      } else {
        break;
      }
    }
    final text = lines[line].text;
    if (text.isEmpty) continue;
    final offset = (global - starts[line]).clamp(0, text.length);
    result.putIfAbsent(line, () => []).add(
          ScriptMarker(
            id: marker.id,
            scriptId: marker.scriptId,
            sectionId: marker.sectionId,
            charOffset: offset,
            kind: marker.kind,
            label: marker.label,
            color: marker.color,
          ),
        );
  }
  return result;
}

/// 把旧版"按句切行"的锚点折算到段落模型（0.22.0 迁移）。
///
/// 旧版每个分段会按句末标点切成多条行，会话表里保存的是那些行的下标；
/// 直接套用到段落模型会明显跳位。这里用同一套旧规则重建旧行，找到锚点
/// 落在哪个分段及段内偏移，再映射回"分段 = 段落行"的新行号。
///
/// [legacyLineChars] 是旧版切行时的每行字数上限。0.17 及更早默认 40；
/// 0.18–0.21 曾按窗口宽度自动计算，此处无法还原，只能按 40 近似，
/// 因此这类旧断点可能偏移少量行（不会越界）。
LegacyAnchorMapping mapLegacyAnchorToParagraphs({
  required List<ScriptSection> sections,
  required List<ScriptLine> lines,
  required int legacyAnchor,
  int legacyLineChars = 40,
}) {
  if (lines.isEmpty) {
    return const LegacyAnchorMapping(line: 0, charOffset: 0);
  }
  final ordered = [...sections]..sort((a, b) => a.ord.compareTo(b.ord));
  final legacy = <({int sectionIndex, int charStart})>[];
  for (var i = 0; i < ordered.length; i++) {
    for (final piece in splitText(ordered[i].text, legacyLineChars)) {
      legacy.add((sectionIndex: i, charStart: piece.start));
    }
  }
  if (legacy.isEmpty) {
    return const LegacyAnchorMapping(line: 0, charOffset: 0);
  }
  final target = legacy[legacyAnchor.clamp(0, legacy.length - 1)];
  // 连续文本渲染后每段仍是一条语义行，按分段顺序落位即可；
  // 不再依赖 line.sectionId（rawText 渲染时是合成 id）。
  final line = target.sectionIndex.clamp(0, lines.length - 1);
  return LegacyAnchorMapping(
    line: line,
    charOffset: target.charStart.clamp(0, lines[line].text.length),
  );
}
