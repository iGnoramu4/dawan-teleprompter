import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

void main() {
  group('LineFit.averageEm', () {
    test('纯中文按全角 1.0em', () {
      expect(LineFit.averageEm('中文台本'), 1.0);
    });

    test('纯英文按半角 0.52em', () {
      expect(LineFit.averageEm('hello'), closeTo(0.52, 1e-9));
    });

    test('中英混排按占比加权', () {
      // 2 个全角 + 2 个半角 → (2*1 + 2*0.52) / 4。
      expect(LineFit.averageEm('中文ab'), closeTo(0.76, 1e-9));
    });

    test('空白与换行不计入占比', () {
      expect(LineFit.averageEm('中 文\n'), 1.0);
    });

    test('空文本回落全角', () {
      expect(LineFit.averageEm(''), 1.0);
      expect(LineFit.averageEm(' \n\t'), 1.0);
    });
  });

  group('LineFit.charsPerLine', () {
    test('按可用宽度与字号估算', () {
      // 1080 屏去掉 14px 留白，字号 44、平均 1em、安全系数 1.02。
      final chars = LineFit.charsPerLine(width: 1080, fontSize: 44);
      expect(chars, ((1080 - 14) / (44 * 1.02)).floor());
    });

    test('字号越大每行字数越少', () {
      final small = LineFit.charsPerLine(width: 800, fontSize: 30);
      final large = LineFit.charsPerLine(width: 800, fontSize: 80);
      expect(large, lessThan(small));
    });

    test('宽度越大每行字数越多', () {
      final narrow = LineFit.charsPerLine(width: 400, fontSize: 44);
      final wide = LineFit.charsPerLine(width: 900, fontSize: 44);
      expect(wide, greaterThan(narrow));
    });

    test('字距占用额外宽度', () {
      final tight = LineFit.charsPerLine(width: 800, fontSize: 44);
      final loose = LineFit.charsPerLine(
        width: 800,
        fontSize: 44,
        letterSpacing: 3,
      );
      expect(loose, lessThan(tight));
    });

    test('平均字宽更窄时能放更多字', () {
      final wide = LineFit.charsPerLine(width: 800, fontSize: 44);
      final narrow = LineFit.charsPerLine(
        width: 800,
        fontSize: 44,
        averageEm: LineFit.narrowEm,
      );
      expect(narrow, greaterThan(wide));
    });

    test('过窄或非法输入被夹到下限', () {
      expect(LineFit.charsPerLine(width: 12, fontSize: 44), LineFit.minChars);
      expect(LineFit.charsPerLine(width: 0, fontSize: 44), LineFit.minChars);
      expect(
        LineFit.charsPerLine(width: double.nan, fontSize: 44),
        LineFit.minChars,
      );
      expect(LineFit.charsPerLine(width: 800, fontSize: 0), LineFit.minChars);
    });

    test('超大宽度被夹到上限', () {
      expect(
        LineFit.charsPerLine(width: 100000, fontSize: 1),
        LineFit.maxChars,
      );
    });

    test('结果始终位于 [minChars, maxChars]', () {
      for (final width in [1.0, 60.0, 320.0, 1080.0, 4000.0]) {
        for (final fontSize in [24.0, 44.0, 96.0, 160.0]) {
          final chars = LineFit.charsPerLine(
            width: width,
            fontSize: fontSize,
          );
          expect(chars, inInclusiveRange(LineFit.minChars, LineFit.maxChars));
        }
      }
    });
  });
}
