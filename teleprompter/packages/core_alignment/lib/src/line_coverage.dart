import 'normalizer.dart';
import 'script_index.dart';

/// 一行台本的读音覆盖度。
class LineCoverage {
  /// 创建覆盖度快照。
  const LineCoverage({
    required this.line,
    required this.matched,
    required this.total,
    required this.farthest,
  });

  /// 行号。
  final int line;

  /// 已命中的有效音节数。
  final int matched;

  /// 该行的有效音节总数。
  final int total;

  /// 最远命中的音节下标（0 起；无命中为 0）。
  final int farthest;

  /// 覆盖率 = 命中音节 / 有效音节。
  double get ratio => total == 0 ? 0 : matched / total;

  /// 最远命中位置比例（防止只读到行首就放行）。
  double get farthestRatio => total == 0 ? 0 : (farthest + 1) / total;

  @override
  String toString() => 'LineCoverage(line=$line, $matched/$total, '
      'ratio=${ratio.toStringAsFixed(2)}, far=${farthestRatio.toStringAsFixed(2)})';
}

/// 行级读音覆盖率累加器。
///
/// 判定单位从「逐字命中」改为「整行覆盖」：识别流里读到的音节按行内顺序
/// 打点，行内个别字漏读/错读/跳词只让覆盖率略降，不会卡住跟随。
///
/// 两个防作弊条件（缺一不可）：
/// 1. 覆盖率达标（按行长分档，见 [requiredCoverage]）；
/// 2. 最远命中位置达标（[minFarthestRatio]）——只读到行首关键词、或者
///    零散同音命中，都无法靠「分子够大」蒙混过关。
///
/// 命中只允许在行内**单调前进**（可跳过最多 [skipWindow] 个音节），
/// 乱序命中不计入；这使噪声很难偶然拼出高覆盖率。
class LineCoverageTracker {
  /// 创建累加器。
  LineCoverageTracker(this.index);

  /// 台本索引。
  final ScriptIndex index;

  /// 行内允许一次跳过的未命中音节数（跳词/口误容忍）。
  static const int skipWindow = 3;

  /// 至少命中多少个音节才算有效证据。
  static const int minMatched = 3;

  /// 最远命中位置下限：最后一击必须落在本行 60% 之后。
  static const double minFarthestRatio = 0.6;

  /// 按行长分档的覆盖率门槛。
  ///
  /// 短行（≤5 音节）一个字的权重太大，要求 90%；长行允许 35% 的漏读。
  static double requiredCoverage(int total) {
    if (total <= 5) return 0.9;
    if (total <= 12) return 0.8;
    if (total <= 25) return 0.72;
    return 0.65;
  }

  int _line = -1;
  List<bool> _hit = const <bool>[];
  int _cursor = 0;

  /// 清空累计（手动跳转 / 停止跟随时调用）。
  void reset() {
    _line = -1;
    _hit = const <bool>[];
    _cursor = 0;
  }

  /// 当前行的覆盖度快照。
  LineCoverage get coverage {
    final total = _hit.length;
    var matched = 0;
    var farthest = 0;
    for (var i = 0; i < total; i++) {
      if (_hit[i]) {
        matched++;
        farthest = i;
      }
    }
    return LineCoverage(
      line: _line,
      matched: matched,
      total: total,
      farthest: farthest,
    );
  }

  /// 用一段识别文本更新 [line] 行的覆盖度。
  LineCoverage update(int line, List<NormToken> spoken) {
    final from = index.startTokenOfLine(line);
    final to = index.endTokenOfLine(line);
    if (line != _line) {
      _line = line;
      _hit = List<bool>.filled(to - from, false);
      _cursor = from;
    }
    if (_hit.isEmpty) return coverage;

    for (final token in spoken) {
      var j = _cursor;
      final limit = _cursor + skipWindow;
      while (j < to && j <= limit) {
        if (index.tokens[j].matches(token)) {
          _hit[j - from] = true;
          _cursor = j + 1;
          break;
        }
        j++;
      }
    }
    return coverage;
  }

  /// 当前行是否达到放行条件。
  bool allowsAdvance(LineCoverage value) {
    if (value.total == 0 || value.matched < minMatched) return false;
    return value.ratio >= requiredCoverage(value.total) &&
        value.farthestRatio >= minFarthestRatio;
  }
}
