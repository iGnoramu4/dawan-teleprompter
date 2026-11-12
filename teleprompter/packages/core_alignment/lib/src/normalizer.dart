import 'package:lpinyin/lpinyin.dart';

import 'latin_terms.dart';

/// 归一化后的一个 token（对齐的最小单位）。
///
/// 中文的一「字」在读音口径下就是一个**音节**，因此 token = 音节；
/// 英文/数字按下面的策略折叠（见 [Normalizer] 文档）后同样只占一个 token。
class NormToken {
  /// 创建一个归一化 token。
  const NormToken({
    required this.raw,
    required this.pinyin,
    required this.fuzzy,
    required this.isLatin,
    required this.srcStart,
    required this.srcEnd,
    this.readings = const <String>{},
    this.tone = 0,
  });

  /// 归一化后的原文（中文单字 / 英文小写单词）。
  final String raw;

  /// 主读音（无声调拼音；英文小写；数字为转换后的中文读法）。
  final String pinyin;

  /// 主读音的模糊等价类。
  final String fuzzy;

  /// 该 token 所有可能读音的模糊等价类（多音字会有多个，至少包含 [fuzzy]）。
  ///
  /// 对齐时只要两边的集合有交集即算命中；分词边界、多音字在词中的读法
  /// 变化都不会把同一段话拆成不同结果。
  final Set<String> readings;

  /// 主读音声调（1–4，0 = 轻声/未知/英文）。仅作加分项，不是硬条件。
  final int tone;

  /// 是否英文/拉丁 token。
  final bool isLatin;

  /// 在输入文本中的起始偏移。
  final int srcStart;

  /// 在输入文本中的结束偏移（不含）。
  final int srcEnd;

  /// 两个 token 是否读音命中。
  ///
  /// 判定顺序（只走读音，没有文字模式）：
  /// 1. 主读音的模糊等价类相同；
  /// 2. 任一侧的候选读音（多音字）相交；
  /// 3. 中文音节之间允许**编辑距离 ≤ 1**（漏读/多读/一个音素不同），
  ///    用来容忍识别把 `xian` 写成 `xie` 这类近似音。
  bool matches(NormToken other) {
    if (fuzzy == other.fuzzy) return true;
    if (readings.isEmpty || other.readings.isEmpty) return false;
    for (final key in readings) {
      if (other.readings.contains(key)) return true;
    }
    if (isLatin || other.isLatin) return false;
    for (final a in readings) {
      for (final b in other.readings) {
        if (Normalizer.nearSyllable(a, b)) return true;
      }
    }
    return false;
  }

  NormToken _withOffsets(int start, int end) => NormToken(
        raw: raw,
        pinyin: pinyin,
        fuzzy: fuzzy,
        readings: readings,
        tone: tone,
        isLatin: isLatin,
        srcStart: start,
        srcEnd: end,
      );

  @override
  String toString() => 'NormToken($raw/$fuzzy)';
}

/// 把台本与识别结果归一化成可比较的 token 流（§5.5 步骤 1）。
///
/// 口径约定：
/// 1. **中文**逐字成 token（一字 = 一个音节），多音字保留全部读音，比较时
///    取交集；因此「银行」读 yin-hang 还是自行切词都不影响命中。
/// 2. **数字**先转成中文口播读法再按音节切分：`12.5%` → `百分之十二点五`，
///    因此台本写数字、识别写成汉字也能对齐。
/// 3. **英文术语整体一个 token**：`SDK` / `Wi-Fi` / `sherpa-onnx` 视为一个
///    整体。理由是 ASR 按「词」输出英文，逐字母对齐会把 `sd` 误当成 `sdk`
///    并破坏字符偏移；被识别流拆开的术语（`I PHONE`）会先合并回一个 token。
/// 4. 标点/空白丢弃，不参与对齐。
class Normalizer {
  /// 创建归一化器（无状态，可复用）。
  ///
  /// [mergeLatinTerms] 控制是否把被拆散的英文术语（`I PHONE`）合并成单个
  /// token。该行为只应作用于**识别结果**：台本作者写的是 `iPhone` 或
  /// `sherpa-onnx`，若也对台本合并，会改变 ScriptIndex 的 token 数与偏移，
  /// 进而把行尾误判成下一行（D1）。因此台本索引用 `false`。
  const Normalizer({
    this.mergeLatinTerms = true,
  });

  /// 是否合并被拆散的拉丁术语（识别流默认开启，台本索引关闭）。
  final bool mergeLatinTerms;

  /// 拼音模糊等价类：只影响比较，不改变拼音本身。
  ///
  /// 按普通话实际混淆规律合并（左右两类互相等价）：
  /// - 平翘舌：zh/ch/sh → z/c/s；
  /// - 尖音：zi-/ci-/si- 与 ji-/qi-/xi-（`zian`/`jian` 等）合并；
  /// - n/l、r/l；
  /// - f/h（`hu`/`fu`）；
  /// - 前后鼻音：ang/an、eng/en、ing/in，以及 iang/ian、uang/uan；
  /// - iu/ou（`liu`/`lou`）。
  static String fuzzyOf(String pinyin) {
    var p = pinyin;
    if (p.startsWith('zh')) {
      p = 'z${p.substring(2)}';
    } else if (p.startsWith('ch')) {
      p = 'c${p.substring(2)}';
    } else if (p.startsWith('sh')) {
      p = 's${p.substring(2)}';
    }
    if (p.startsWith('n')) p = 'l${p.substring(1)}';
    if (p.startsWith('r')) p = 'l${p.substring(1)}';
    if (p.startsWith('f')) p = 'h${p.substring(1)}';
    p = p.replaceAll('uang', 'uan');
    p = p.replaceAll('iang', 'ian');
    p = p.replaceAll('iu', 'ou');
    p = p.replaceAll('ing', 'in');
    p = p.replaceAll('eng', 'en');
    p = p.replaceAll('ang', 'an');
    return p;
  }

  /// 两个音节是否「近似音」：编辑距离 ≤ 1（一处替换/漏读/多读）。
  ///
  /// 只用于中文音节，且要求声母相同——声母不同（t/x、m/n）的差异已由
  /// 上面的等价类覆盖，不能再放开，否则会把「妈/拿」这类无关字合并。
  static bool nearSyllable(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty || a.codeUnitAt(0) != b.codeUnitAt(0)) {
      return false;
    }
    final la = a.length;
    final lb = b.length;
    if ((la - lb).abs() > 1) return false;
    var i = 0;
    while (i < la && i < lb && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    if (la == lb) {
      return i + 1 >= la ? true : a.substring(i + 1) == b.substring(i + 1);
    }
    // 长度差 1：跳过较长串的一个字符后必须完全相同。
    return la > lb
        ? a.substring(i + 1) == b.substring(i)
        : a.substring(i) == b.substring(i + 1);
  }

  /// 把文本归一化为 token 流。
  List<NormToken> normalize(String text) {
    final result = <NormToken>[];
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (_isDigit(ch)) {
        final start = i;
        while (i < text.length && (_isDigit(text[i]) || text[i] == '.')) {
          i++;
        }
        var hasPercent = false;
        if (i < text.length && text[i] == '%') {
          hasPercent = true;
          i++;
        }
        final reading = _numberToReading(
            text.substring(start, i).replaceAll('%', ''), hasPercent);
        _appendChinese(result, reading, start, i);
        continue;
      }
      if (_isLatinLetter(ch)) {
        final start = i;
        while (i < text.length && _isLatinLetter(text[i])) {
          i++;
        }
        final word = text.substring(start, i).toLowerCase();
        result.add(
          NormToken(
            raw: word,
            pinyin: word,
            fuzzy: word,
            readings: _literalReadings(word),
            isLatin: true,
            srcStart: start,
            srcEnd: i,
          ),
        );
        continue;
      }
      if (ChineseHelper.isChinese(ch)) {
        final start = i;
        while (i < text.length && ChineseHelper.isChinese(text[i])) {
          i++;
        }
        _appendChineseRun(result, text.substring(start, i), start);
        continue;
      }
      // 标点、空白、符号：丢弃（对齐前统一去标点）。
      i++;
    }
    return mergeLatinTerms ? _mergeLatinTerms(result) : result;
  }

  /// 术语表按「折叠重复字母后的写法」建索引：`wii fi` → `wiifi` → `wifi`。
  static final Map<String, String> _termIndex = {
    for (final term in latinTerms) _collapseRepeats(term): term,
  };

  /// 相邻拉丁 token 最多合并 4 段，避免把整句英文吞成一个 token。
  static const int _maxMergeSpan = 4;

  /// 把被拆散的同一条术语合并成单个 token（`I PHONE` → `iphone`）。
  ///
  /// 只有拼接结果（折叠重复字母后）命中 [latinTerms] 才合并，普通英文短语
  /// 不会被误并。逐次尝试更长的跨度，取最长匹配。
  List<NormToken> _mergeLatinTerms(List<NormToken> tokens) {
    final out = <NormToken>[];
    var i = 0;
    while (i < tokens.length) {
      if (!tokens[i].isLatin) {
        out.add(tokens[i]);
        i++;
        continue;
      }
      var merged = false;
      final limit = i + _maxMergeSpan;
      final upper = limit < tokens.length ? limit : tokens.length;
      for (var j = upper; j > i + 1; j--) {
        final span = tokens.sublist(i, j);
        if (!span.every((t) => t.isLatin)) continue;
        final concat = span.map((t) => t.raw).join();
        final term = _termIndex[_collapseRepeats(concat)];
        if (term == null) continue;
        out.add(
          NormToken(
            raw: term,
            pinyin: term,
            fuzzy: term,
            readings: _literalReadings(term),
            isLatin: true,
            srcStart: span.first.srcStart,
            srcEnd: span.last.srcEnd,
          ),
        );
        i = j;
        merged = true;
        break;
      }
      if (merged) continue;
      out.add(tokens[i]);
      i++;
    }
    return out;
  }

  /// 连续重复字母折叠：`wiifi` → `wifi`（仅用于匹配，不改变输出）。
  static String _collapseRepeats(String s) {
    final buffer = StringBuffer();
    var prev = '';
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch != prev) buffer.write(ch);
      prev = ch;
    }
    return buffer.toString();
  }

  /// 把一个连续中文片段切成音节 token。
  ///
  /// 先用 lpinyin 的词语多音字表做最长匹配取得**上下文主读音**（`银行` →
  /// yin/hang），再把该字的全部读音作为候选集合，保证切词方式不影响命中。
  void _appendChineseRun(List<NormToken> out, String run, int srcStart) {
    var i = 0;
    while (i < run.length) {
      if (run.length - i >= 2) {
        final multi = PinyinHelper.convertToMultiPinyin(
          run.substring(i),
          ',',
          PinyinFormat.WITH_TONE_NUMBER,
        );
        if (multi != null && multi.word != null && multi.pinyin != null) {
          final word = multi.word!;
          final syllables = multi.pinyin!
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(growable: false);
          if (syllables.length == word.length) {
            for (var k = 0; k < word.length; k++) {
              out.add(_chineseToken(word[k], srcStart + i + k, syllables[k]));
            }
            i += word.length;
            continue;
          }
        }
      }
      out.add(_chineseToken(run[i], srcStart + i, null));
      i++;
    }
  }

  /// 构造单字音节 token。
  ///
  /// [primaryWithTone] 是上下文主读音（如 `hang2`）；为空时取该字的第一读音。
  NormToken _chineseToken(String ch, int start, String? primaryWithTone) {
    final all = _allReadings(ch);
    final primary =
        primaryWithTone ?? (all.isNotEmpty ? all.first : _safePinyin(ch));
    final tone = _toneOf(primary);
    final pinyin = _stripTone(primary);
    return NormToken(
      raw: ch,
      pinyin: pinyin,
      fuzzy: _fuzzyKey(pinyin, ch),
      readings: _readingsOf(pinyin, all),
      tone: tone,
      isLatin: false,
      srcStart: start,
      srcEnd: start + ch.length,
    );
  }

  /// 把一个中文读法片段追加为 token，字符偏移夹回原文区间。
  void _appendChinese(
      List<NormToken> out, String text, int srcStart, int srcEnd) {
    final run = <NormToken>[];
    _appendChineseRun(run, text, srcStart);
    for (var i = 0; i < run.length; i++) {
      // 数字读法的字符数可能多于原文（如 80% → 百分之八十），偏移夹在原文区间内。
      final offset = (srcStart + i).clamp(srcStart, srcEnd - 1);
      out.add(run[i]._withOffsets(offset, offset + 1));
    }
  }

  String _safePinyin(String ch) {
    try {
      final pinyin = PinyinHelper.getPinyin(ch, separator: '');
      return pinyin.isEmpty || pinyin.contains(' ') ? ch : pinyin;
    } catch (_) {
      return ch;
    }
  }

  /// 该字的全部读音（带声调数字，如 `hang2`）。
  List<String> _allReadings(String ch) {
    try {
      return PinyinHelper.convertToPinyinArray(
        ch,
        PinyinFormat.WITH_TONE_NUMBER,
      );
    } catch (_) {
      return const [];
    }
  }

  Set<String> _readingsOf(String primary, List<String> all) {
    final keys = <String>{fuzzyOf(primary)};
    for (final item in all) {
      final syllable = _stripTone(item);
      if (syllable.isEmpty) continue;
      keys.add(fuzzyOf(syllable));
    }
    return keys;
  }

  /// 英文/拉丁 token 整体作为一个读音单元，不做逐字母切分。
  Set<String> _literalReadings(String raw) => {raw};

  String _fuzzyKey(String pinyin, String fallback) {
    return pinyin.isEmpty ? fallback : fuzzyOf(pinyin);
  }

  static int _toneOf(String syllable) {
    if (syllable.isEmpty) return 0;
    final last = syllable.codeUnitAt(syllable.length - 1);
    if (last >= 49 && last <= 53) return last - 48;
    return 0;
  }

  static String _stripTone(String syllable) =>
      syllable.replaceAll(RegExp('[0-9]'), '');

  String _numberToReading(String raw, bool percent) {
    final parts = raw.split('.');
    final integer = parts.first;
    final buffer = StringBuffer();
    if (integer.length >= 3 ||
        (integer.length > 1 && integer.startsWith('0'))) {
      for (final ch in integer.split('')) {
        buffer.write(_digitChar(ch));
      }
    } else {
      buffer.write(_twoDigitReading(int.tryParse(integer) ?? 0));
    }
    if (parts.length > 1) {
      buffer.write('点');
      for (final ch in parts[1].split('')) {
        buffer.write(_digitChar(ch));
      }
    }
    if (percent) return '百分之${buffer.toString()}';
    return buffer.toString();
  }

  String _digitChar(String ch) {
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final n = int.tryParse(ch);
    if (n == null || n < 0 || n > 9) return '';
    return digits[n];
  }

  String _twoDigitReading(int n) {
    if (n <= 9) return _digitChar('$n');
    if (n == 10) return '十';
    if (n < 20) return '十${_digitChar('${n % 10}')}';
    final tens = _digitChar('${n ~/ 10}');
    final ones = n % 10;
    return ones == 0 ? '$tens十' : '$tens十${_digitChar('$ones')}';
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  bool _isLatinLetter(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }
}
