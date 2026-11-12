import 'package:core_reader_layout/core_reader_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/visual_row_measurer.dart';

const _style = TextStyle(fontSize: 32, height: 1.4);

FlutterRowMeasurer _measurer({double fontSize = 32, double scale = 1.0}) {
  return FlutterRowMeasurer(
    style: _style.copyWith(fontSize: fontSize),
    textScaler: TextScaler.linear(scale),
    align: TextAlign.start,
  );
}

/// 拼接所有视觉行文本里的非换行字符，应与原文去掉硬换行后一致。
String _flatten(List<MeasuredRow> rows) => rows.map((row) => row.text).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterRowMeasurer 段内换行', () {
    test('段内换行切成两条视觉行，换行后的文字仍在行文本里', () {
      final rows = _measurer().measure('AAA_BEFORE\nBBB_AFTER', maxWidth: 2000);

      expect(rows.map((row) => row.text).toList(), [
        'AAA_BEFORE',
        'BBB_AFTER',
      ]);
      for (final row in rows) {
        expect(row.text.contains('\n'), isFalse);
        expect(row.height, greaterThan(0));
      }
      expect(rows[0].charStart, 0);
      expect(rows[0].charEnd, 10);
      // 跳过换行符：第二条视觉行从原文下标 11 开始。
      expect(rows[1].charStart, 11);
      expect(rows[1].charEnd, 20);
    });

    test(r'CRLF 只产生一次断行且偏移正确', () {
      final rows = _measurer().measure('AAA\r\nBBB', maxWidth: 2000);

      expect(rows.map((row) => row.text).toList(), ['AAA', 'BBB']);
      expect(rows[1].charStart, 5);
      expect(rows[1].charEnd, 8);
    });

    test('空硬行保留为空视觉行，不被合并或丢弃', () {
      final rows = _measurer().measure('甲\n\n乙', maxWidth: 2000);

      expect(rows.map((row) => row.text).toList(), ['甲', '', '乙']);
      expect(rows[1].charStart, 2);
      expect(rows[1].charEnd, 2);
      expect(rows[2].charStart, 3);
    });

    test('空段落与结尾换行不丢内容', () {
      final rows = _measurer().measure('甲\n', maxWidth: 2000);

      expect(rows.map((row) => row.text).toList(), ['甲', '']);
    });

    test('多字号 × 多宽度：不产生含换行的行，且字符完整覆盖', () {
      const text = '第一行比较长需要按宽度自然折行才能放下所有字。\n'
          '第二行换行后必须显示出来。\n'
          '\n'
          '第三段内容。';
      final expected = text.replaceAll('\n', '');
      for (final fontSize in <double>[20, 32, 48, 72]) {
        for (final width in <double>[160, 240, 360, 720]) {
          for (final scale in <double>[1.0, 1.3]) {
            final rows = _measurer(fontSize: fontSize, scale: scale)
                .measure(text, maxWidth: width);
            final label = 'fs=$fontSize w=$width scale=$scale';
            expect(rows, isNotEmpty, reason: label);
            for (final row in rows) {
              expect(row.text.contains('\n'), isFalse, reason: label);
              expect(row.text.contains('\r'), isFalse, reason: label);
              expect(row.height, greaterThan(0), reason: label);
            }
            expect(_flatten(rows), expected, reason: label);
            // 行区间必须连续且落在原文范围内。
            var cursor = 0;
            for (final row in rows) {
              expect(row.charStart, greaterThanOrEqualTo(cursor),
                  reason: label);
              expect(row.charEnd, greaterThanOrEqualTo(row.charStart),
                  reason: label);
              cursor = row.charEnd;
            }
          }
        }
      }
    });
  });
}
