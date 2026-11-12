/// 导入清洗（§4.1 S-04/S-05/S-09）。
///
/// 纯字符串处理，不做分词，不依赖平台能力。
library;

import 'script_model.dart';

/// 导入清洗开关集合。
class CleanOptions {
  /// 创建清洗开关。
  const CleanOptions({
    this.mergeHardLineBreaks = false,
    this.stripHeadersFooters = true,
    this.normalizeWidth = true,
    this.collapseBlankLines = true,
    this.stripMarkdown = false,
  });

  /// 合并段内硬换行（PDF/网页复制常见的一句话被折断）。
  final bool mergeHardLineBreaks;

  /// 去掉纯页码/页眉页脚行。
  final bool stripHeadersFooters;

  /// 全角字母、数字、空格转半角。
  final bool normalizeWidth;

  /// 多行空行压缩为单空行。
  final bool collapseBlankLines;

  /// 轻度剥离 Markdown 标记（`#`、`**`、列表符号）。
  final bool stripMarkdown;

  /// 复制并按需替换开关。
  CleanOptions copyWith({
    bool? mergeHardLineBreaks,
    bool? stripHeadersFooters,
    bool? normalizeWidth,
    bool? collapseBlankLines,
    bool? stripMarkdown,
  }) {
    return CleanOptions(
      mergeHardLineBreaks: mergeHardLineBreaks ?? this.mergeHardLineBreaks,
      stripHeadersFooters: stripHeadersFooters ?? this.stripHeadersFooters,
      normalizeWidth: normalizeWidth ?? this.normalizeWidth,
      collapseBlankLines: collapseBlankLines ?? this.collapseBlankLines,
      stripMarkdown: stripMarkdown ?? this.stripMarkdown,
    );
  }
}

final RegExp _sentenceEnd = RegExp(r'[。！？!?；;：:…”"」』）)]');
final RegExp _pageNumber = RegExp(
  r'^\s*[-–—]?\s*\d+\s*[-–—]?\s*$|'
  r'^\s*第\s*\d+\s*页\s*$|'
  r'^\s*page\s*\d+(\s*(of|/)\s*\d+)?\s*$',
  caseSensitive: false,
);
final RegExp _markdownNoise = RegExp(
  r'^(\s*#{1,6}\s*|\s*[-*+]\s+|\s*>+\s*)|(\*\*|__|\*|_|`{1,3}|\[([^\]]*)\]\([^)]*\))',
);

/// 按开关清洗导入文本，返回去掉首尾空白的正文。
String cleanImportedText(String raw, CleanOptions options) {
  var text = normalizeNewlines(raw);

  if (options.normalizeWidth) text = normalizeWidth(text);
  if (options.stripMarkdown) text = stripMarkdown(text);

  var lines = text.split('\n').toList();
  if (options.stripHeadersFooters) {
    lines = lines.where((line) => !_isPageFurniture(line)).toList();
  }

  if (options.mergeHardLineBreaks) {
    lines = _mergeHardBreaks(lines);
  }

  text = lines.join('\n');
  if (options.collapseBlankLines) {
    text = text.replaceAll(RegExp(r'\n[ \t]*\n[ \t]*\n+'), '\n\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
  return text.trim();
}

/// 全角 ASCII（FF01–FF5E）中的字母/数字转半角，全角空格转普通空格。
///
/// 全角标点（，。！？：等）保持原样，避免中文正文被改成英文标点。
String normalizeWidth(String text) {
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code == 0x3000) {
      buffer.write(' ');
      continue;
    }
    if (code >= 0xFF01 && code <= 0xFF5E) {
      final half = code - 0xFEE0;
      final isLatinOrDigit = (half >= 0x30 && half <= 0x39) ||
          (half >= 0x41 && half <= 0x5A) ||
          (half >= 0x61 && half <= 0x7A);
      if (isLatinOrDigit) {
        buffer.writeCharCode(half);
        continue;
      }
    }
    buffer.writeCharCode(code);
  }
  return buffer.toString();
}

/// 轻度 Markdown 清理：保留文字，去掉标题/列表/强调符号与链接目标。
String stripMarkdown(String text) {
  final lines = <String>[];
  for (final raw in text.split('\n')) {
    var line = raw;
    if (line.trimLeft().startsWith('```')) {
      continue;
    }
    line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
    line = line.replaceFirst(RegExp(r'^\s*>\s*'), '');
    line = line.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\((?:[^)]*)\)'),
      (match) => match.group(1) ?? '',
    );
    line = line.replaceAll(_markdownNoise, '');
    lines.add(line);
  }
  return lines.join('\n');
}

/// 取首个非空行作为默认标题（最多 30 字）。
///
/// [fallback] 在正文为空时返回，UI 层可传入本地化文案。
String suggestTitle(String text, {String fallback = '未命名台本'}) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final cleaned = trimmed.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
    if (cleaned.isEmpty) continue;
    return cleaned.length <= 30 ? cleaned : '${cleaned.substring(0, 30)}…';
  }
  return fallback;
}

bool _isPageFurniture(String line) => _pageNumber.hasMatch(line.trim());

/// 段内（没有空行分隔）把被折断的行接回上一行。
List<String> _mergeHardBreaks(List<String> lines) {
  final result = <String>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      result.add('');
      continue;
    }
    if (result.isEmpty || result.last.isEmpty) {
      result.add(line);
      continue;
    }
    final prev = result.last;
    final endsSentence = _sentenceEnd.hasMatch(prev);
    if (endsSentence) {
      result.add(line);
      continue;
    }
    final needsSpace = _isLatin(prev) && _isLatin(line);
    result[result.length - 1] = needsSpace ? '$prev $line' : '$prev$line';
  }
  return result;
}

bool _isLatin(String text) {
  if (text.isEmpty) return false;
  final code = text.codeUnitAt(text.length - 1);
  return (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}
