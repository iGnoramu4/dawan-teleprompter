import 'package:core_alignment/core_alignment.dart';

/// 编辑距离（按 token 序列）。
int editDistance(List<String> a, List<String> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      var best = del < ins ? del : ins;
      if (sub < best) best = sub;
      cur[j] = best;
    }
    final tmp = List<int>.from(cur);
    for (var k = 0; k <= b.length; k++) {
      prev[k] = tmp[k];
    }
  }
  return prev[b.length];
}

/// CER 结果。
class CerResult {
  const CerResult({
    required this.cer,
    required this.distance,
    required this.refLength,
    required this.hypothesis,
    required this.reference,
  });

  final double cer;
  final int distance;
  final int refLength;
  final String hypothesis;
  final String reference;
}

/// 用与产品一致的归一化器切 token，再按 token 计算 CER。
///
/// 中文按字、英文按整词、数字转中文读法；标点与空白不计入。
CerResult computeCer(String hypothesis, String reference) {
  const normalizer = Normalizer();
  final hypTokens = normalizer.normalize(hypothesis).map((t) => t.raw).toList();
  final refTokens = normalizer.normalize(reference).map((t) => t.raw).toList();
  final dist = editDistance(hypTokens, refTokens);
  final length = refTokens.length;
  return CerResult(
    cer: length == 0 ? (dist == 0 ? 0 : 1) : dist / length,
    distance: dist,
    refLength: length,
    hypothesis: hypTokens.join(),
    reference: refTokens.join(),
  );
}
