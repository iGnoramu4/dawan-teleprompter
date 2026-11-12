import 'package:core_alignment/core_alignment.dart';
import 'package:test/test.dart';

/// 读音匹配回归（0.25.0 / 0.27.0）。
///
/// 覆盖：同音字、近音字（z/zh、n/l、r/l、f/h、前后鼻音、iu/ou）、
/// 多音字、数字口播、英文术语、分词边界一致性，以及音节级编辑距离。
void main() {
  const phonetic = Normalizer();

  List<String> pinyinSeq(String text) =>
      phonetic.normalize(text).map((t) => t.fuzzy).toList();

  group('同音字替换', () {
    test('重点 / 终点 读音命中', () {
      final a = phonetic.normalize('重点');
      final b = phonetic.normalize('终点');
      expect(a[0].matches(b[0]), isTrue);
      expect(a[1].matches(b[1]), isTrue);
    });

    test('整句同音替换仍高置信命中当前行', () {
      final index = ScriptIndex.build(['这是重点']);
      final result = AlignEngine(index).align('这是终点', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      // 重/终 声调不同，只扣 0.1 的加分项，不改变命中。
      expect(result.confidence, greaterThan(0.95));
    });
  });

  group('近音字', () {
    test('平翘舌 z/zh', () {
      expect(phonetic.normalize('知道')[0].matches(phonetic.normalize('滋道')[0]),
          isTrue);
      expect(phonetic.normalize('测试')[0].matches(phonetic.normalize('策试')[0]),
          isTrue);
    });

    test('n/l 不分', () {
      expect(phonetic.normalize('那里')[0].matches(phonetic.normalize('辣里')[0]),
          isTrue);
      expect(phonetic.normalize('牛奶')[0].matches(phonetic.normalize('流奶')[0]),
          isTrue);
    });

    test('前后鼻音 -in/-ing、-an/-ang、-en/-eng', () {
      expect(phonetic.normalize('应该')[0].matches(phonetic.normalize('因该')[0]),
          isTrue);
      expect(phonetic.normalize('醒来')[0].matches(phonetic.normalize('行来')[0]),
          isTrue);
      expect(phonetic.normalize('根本')[0].matches(phonetic.normalize('耕本')[0]),
          isTrue);
    });

    test('f/h 混淆：福/湖', () {
      expect(phonetic.normalize('湖南')[0].matches(phonetic.normalize('福南')[0]),
          isTrue);
      expect(phonetic.normalize('开会')[1].matches(phonetic.normalize('开费')[1]),
          isTrue);
    });

    test('r/l 混淆：肉/漏', () {
      expect(phonetic.normalize('肉')[0].matches(phonetic.normalize('漏')[0]),
          isTrue);
      expect(phonetic.normalize('日')[0].matches(phonetic.normalize('力')[0]),
          isTrue);
    });

    test('韵母混读 iu/ou：牛/流', () {
      expect(phonetic.normalize('牛')[0].matches(phonetic.normalize('流')[0]),
          isTrue);
    });
  });

  group('音节级编辑距离', () {
    test('一处漏读/替换仍算命中', () {
      expect(Normalizer.nearSyllable('tian', 'tia'), isTrue);
      expect(Normalizer.nearSyllable('tian', 'tin'), isTrue);
      expect(Normalizer.nearSyllable('tian', 'xian'), isFalse);
      expect(Normalizer.nearSyllable('tian', 'tuan'), isTrue);
      expect(Normalizer.nearSyllable('tian', 'ting'), isFalse);
      expect(Normalizer.nearSyllable('tian', 'tan'), isTrue);
      expect(Normalizer.nearSyllable('tian', 'tian'), isTrue);
    });

    test('天（tian）与 听（ting→tin）整句仍命中', () {
      final index = ScriptIndex.build(['明天开始演示']);
      final result = AlignEngine(index).align('明听开始演示', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      expect(result.confidence, greaterThan(0.85));
    });

    test('英文整词不走编辑距离', () {
      expect(Normalizer.nearSyllable('rest', 'test'), isFalse);
      final a = phonetic.normalize('REST');
      final b = phonetic.normalize('TEST');
      expect(a.single.matches(b.single), isFalse);
    });
  });

  group('多音字', () {
    test('银行 的行按词语读 hang，仍保留 xing 作为候选', () {
      final tokens = phonetic.normalize('银行');
      expect(tokens.length, 2);
      expect(tokens[1].pinyin, 'hang');
      expect(tokens[1].tone, 2);
      expect(tokens[1].readings, contains(Normalizer.fuzzyOf('hang')));
      expect(tokens[1].readings, contains(Normalizer.fuzzyOf('xing')));
    });

    test('识别成 银航（hang）与 银形（xing）都能命中', () {
      final index = ScriptIndex.build(['我们去银行办理业务']);
      final hang = AlignEngine(index).align('我们去银航办理业务', currentLine: 0);
      final xing = AlignEngine(index).align('我们去银形办理业务', currentLine: 0);
      expect(hang!.confidence, 1.0);
      expect(xing!.confidence, 1.0);
    });

    test('重要 / 众要（zhong）命中', () {
      final index = ScriptIndex.build(['这是非常重要的项目']);
      final result = AlignEngine(index).align('这是众要的项目', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
    });

    test('了 的轻声与 liao 读法都保留', () {
      final token = phonetic.normalize('了')[0];
      expect(token.readings, contains(Normalizer.fuzzyOf('le')));
      expect(token.readings, contains(Normalizer.fuzzyOf('liao')));
    });
  });

  group('数字读法', () {
    test('12.5% 转成 百分之十二点五', () {
      final tokens = phonetic.normalize('12.5%');
      expect(tokens.map((t) => t.raw).join(), '百分之十二点五');
    });

    test('台本写数字、识别写汉字仍满置信对齐', () {
      final index = ScriptIndex.build(['今年增长12.5%']);
      final result = AlignEngine(index).align('今年增长百分之十二点五', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.anchorLine, 0);
      expect(result.confidence, 1.0);
    });

    test('数字偏移夹回原文区间，不越界', () {
      const text = '增长12.5%';
      final tokens = phonetic.normalize(text);
      for (final token in tokens) {
        expect(token.srcStart, greaterThanOrEqualTo(0));
        expect(token.srcEnd, lessThanOrEqualTo(text.length));
        expect(token.srcStart, lessThan(token.srcEnd));
      }
    });
  });

  group('英文术语', () {
    test('英文整体一个 token，不做逐字母对齐', () {
      final tokens = phonetic.normalize('SDK');
      expect(tokens.length, 1);
      expect(tokens.single.raw, 'sdk');
    });

    test('被拆开的 SDK 合并回一个 token', () {
      expect(phonetic.normalize('S D K').map((t) => t.raw).toList(), ['sdk']);
    });

    test('Wi-Fi / WIFI / WII FI 归一化一致', () {
      final expected = phonetic.normalize('Wi-Fi').map((t) => t.raw).toList();
      expect(expected, ['wifi']);
      expect(phonetic.normalize('WIFI').map((t) => t.raw).toList(), expected);
      expect(phonetic.normalize('WII FI').map((t) => t.raw).toList(), expected);
    });

    test('中英混排整句对齐', () {
      final index = ScriptIndex.build(['我们把音频流交给 SDK 处理']);
      final result =
          AlignEngine(index).align('我们把音频流交给 sdk 处理', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.confidence, greaterThan(0.95));
    });
  });

  group('分词边界不影响结果', () {
    test('空格/切词差异不改变音节序列', () {
      expect(pinyinSeq('我们今天讨论人工智能'), pinyinSeq('我们今天 讨论 人工智能'));
    });

    test('识别结果插空格仍满置信命中', () {
      final index = ScriptIndex.build(['我们今天讨论人工智能的应用']);
      final result =
          AlignEngine(index).align('我们今天 讨论 人工智能 的应用', currentLine: 0);
      expect(result, isNotNull);
      expect(result!.confidence, 1.0);
    });
  });

  group('读音单一口径', () {
    test('同音替换只扣声调加分', () {
      final index = ScriptIndex.build(['这是重点']);
      final homophone = AlignEngine(index).align('这是终点', currentLine: 0);
      expect(homophone!.confidence, greaterThan(0.95));
    });

    test('原文一致时满置信', () {
      final index = ScriptIndex.build(['这是重点']);
      final exact = AlignEngine(index).align('这是重点', currentLine: 0);
      expect(exact!.confidence, 1.0);
    });

    test('同音字仍然命中（没有文字回退分支）', () {
      final a = phonetic.normalize('重点');
      final b = phonetic.normalize('终点');
      expect(a[0].matches(b[0]), isTrue);
      expect(a[1].matches(b[1]), isTrue);
    });
  });

  group('声调只做加分项', () {
    test('读音相同、声调不同仍算命中', () {
      final a = phonetic.normalize('了').single;
      final b = phonetic.normalize('聊').single;
      expect(a.tone, isNot(b.tone));
      expect(a.matches(b), isTrue);
    });
  });
}
