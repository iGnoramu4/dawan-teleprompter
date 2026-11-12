import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

/// 从 `.docx` 提取纯文本：按段落拼接，保留段内换行与制表符，忽略图片/表格结构。
///
/// 失败时抛 [FormatException]。
String extractDocxText(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('invalid docx archive');
  }
  ArchiveFile? entry;
  for (final file in archive.files) {
    if (file.name == 'word/document.xml') {
      entry = file;
      break;
    }
  }
  if (entry == null) {
    throw const FormatException('docx has no word/document.xml');
  }

  final XmlDocument document;
  try {
    document = XmlDocument.parse(
      utf8.decode(entry.content as List<int>, allowMalformed: true),
    );
  } catch (_) {
    throw const FormatException('invalid docx xml');
  }

  final paragraphs = <String>[];
  for (final paragraph in document.findAllElements('w:p')) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants.whereType<XmlElement>()) {
      switch (node.name.toString()) {
        case 'w:t':
          buffer.write(node.innerText);
        case 'w:tab':
          buffer.write('\t');
        case 'w:br':
        case 'w:cr':
          buffer.write('\n');
      }
    }
    paragraphs.add(buffer.toString());
  }
  final text = paragraphs.join('\n').trim();
  if (text.isEmpty) {
    throw const FormatException('docx has no text');
  }
  return text;
}

/// 从 `.pdf` 提取文本（按页顺序，带段落换行）。
///
/// 扫描版/纯图片 PDF 没有文本层，会抛 [FormatException]。
Future<String> extractPdfText(Uint8List bytes) async {
  final document = await PdfDocument.openData(bytes);
  try {
    final pages = <String>[];
    for (final page in document.pages) {
      final text = await page.loadStructuredText();
      final content = text.fullText.trim();
      if (content.isNotEmpty) pages.add(content);
    }
    final result = pages.join('\n\n');
    if (result.isEmpty) {
      throw const FormatException('pdf has no text layer');
    }
    return result;
  } finally {
    await document.dispose();
  }
}
