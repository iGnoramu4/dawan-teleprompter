import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/utils/document_import.dart';

Uint8List _docx(String documentXml) {
  final bytes = utf8.encode(documentXml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('docx 提取段落、段内换行与制表符', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>第一段第一句。</w:t><w:br/><w:t>第一段第二句。</w:t></w:r></w:p>
    <w:p><w:r><w:t>第二段</w:t><w:tab/><w:t>备注</w:t></w:r></w:p>
  </w:body>
</w:document>
''';
    final text = extractDocxText(_docx(xml));
    expect(text, '第一段第一句。\n第一段第二句。\n第二段\t备注');
  });

  test('非 zip 内容抛出 FormatException', () {
    expect(
      () => extractDocxText(Uint8List.fromList(utf8.encode('not a docx'))),
      throwsFormatException,
    );
  });

  test('缺少 word/document.xml 抛出 FormatException', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('word/styles.xml', '<styles/>'));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    expect(() => extractDocxText(bytes), throwsFormatException);
  });
}
