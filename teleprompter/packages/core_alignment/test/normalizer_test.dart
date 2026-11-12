import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

/// 归一化层回归：英文术语拆分合并 + 不误并普通英文短语。
void main() {
  const normalizer = Normalizer();

  List<String> raws(String text) =>
      normalizer.normalize(text).map((t) => t.raw).toList();

  group('英文术语合并', () {
    test('I PHONE 与 iPhone 归一化一致', () {
      expect(raws('I PHONE'), raws('iPhone'));
      expect(raws('I PHONE'), ['iphone']);
    });

    test('WIFI / Wi-Fi / WII FI 归一化一致', () {
      final expected = raws('Wi-Fi');
      expect(expected, ['wifi']);
      expect(raws('WIFI'), expected);
      expect(raws('WII FI'), expected);
    });

    test('sherpa-onnx 被拆成两段时合并', () {
      expect(raws('sherpa onnx'), ['sherpaonnx']);
      expect(raws('SHERPA-ONNX'), ['sherpaonnx']);
    });

    test('大小写不影响合并结果', () {
      expect(raws('IPHONE'), ['iphone']);
      expect(raws('i Phone'), ['iphone']);
    });

    test('合并 token 保留原文偏移区间', () {
      const text = '用 I PHONE 演示';
      final tokens = normalizer.normalize(text);
      final phone = tokens.firstWhere((t) => t.raw == 'iphone');
      expect(phone.srcStart, text.indexOf('I'));
      expect(phone.srcEnd, text.indexOf('PHONE') + 'PHONE'.length);
    });

    test('中文夹英文术语只合并英文部分', () {
      expect(raws('现场用的是 iPhone 和安卓双端同步'), [
        '现',
        '场',
        '用',
        '的',
        '是',
        'iphone',
        '和',
        '安',
        '卓',
        '双',
        '端',
        '同',
        '步'
      ]);
    });
  });

  group('普通英文短语不误并', () {
    test('两个普通单词保持独立', () {
      expect(raws('we can'), ['we', 'can']);
      expect(raws('the model is good'), ['the', 'model', 'is', 'good']);
    });

    test('长句不会被吞成单 token', () {
      expect(raws('I have a phone').length, 4);
      expect(raws('so on').length, 2);
      expect(raws('open the door').length, 3);
    });

    test('术语前缀不误并后续词', () {
      // `phone` 本身不是术语，只有 `i`+`phone` 才是。
      expect(raws('phone case'), ['phone', 'case']);
      // `api` 是术语，但 `api`+`key` 不是。
      expect(raws('api key'), ['api', 'key']);
    });
  });

  group('D1 术语合并只作用于识别流', () {
    test('台本索引保留原文 token 划分（不合并 sherpa-onnx）', () {
      final index = ScriptIndex.build([
        '这个功能依赖 sherpa-onnx。',
        '我们把音频流交给 SDK。',
      ]);
      expect(
        index.tokens.map((t) => t.raw).toList(),
        [
          '这',
          '个',
          '功',
          '能',
          '依',
          '赖',
          'sherpa',
          'onnx',
          '我',
          '们',
          '把',
          '音',
          '频',
          '流',
          '交',
          '给',
          'sdk'
        ],
      );
      expect(index.startTokenOfLine(1), 8);
    });

    test('识别流仍合并被拆开的术语', () {
      const recognition = Normalizer();
      expect(
        recognition.normalize('SHERPA ONNX').map((t) => t.raw).toList(),
        ['sherpaonnx'],
      );
    });

    test('行尾术语不会把候选行推到下一行', () {
      final index = ScriptIndex.build([
        '这个功能依赖 Flutter 的插件体系底层是 sherpa-onnx。',
        '我们把音频流交给 SDK。',
      ]);
      final result = AlignEngine(index).align(
        '这个功能依赖觉得插件体系底层是声音',
        currentLine: 0,
      );
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
    });
  });
}
