/// 时间窗口内的**跳行**预算（跳行 = 一次前进超过 1 行）。
///
/// 单步 3 行上限只夹单次：跳过 3 行、再跳 3 行、再跳 3 行，累计仍然能冲出
/// 很远。这里在滚动入口处再加一道累计闸——任意 [window] 内跳行总和不超过
/// [maxJumpLines]，用尽后只允许逐行推进（+1），不再跳行。
///
/// 逐行推进不计入预算：正常朗读本来就会持续前进，若把它也算进去，预算会
/// 长期处于用尽状态，表现为「永远不能跨行」，反而变成卡住。
class AutoAdvanceBudget {
  /// 创建预算；默认「任意 10 秒内跳行总和 ≤3 行」。
  AutoAdvanceBudget({
    this.window = const Duration(seconds: 10),
    this.maxJumpLines = 3,
  });

  /// 统计窗口。
  final Duration window;

  /// 窗口内允许的跳行总行数。
  final int maxJumpLines;

  final List<_Jump> _jumps = <_Jump>[];

  /// 窗口毫秒数。
  int get windowMs => window.inMilliseconds;

  /// 把目标行夹到预算允许的范围。
  ///
  /// [from] 是当前显示行，[to] 是本条证据希望到达的行，[nowMs] 是单调时间。
  /// 超出预算时返回 `from + 1`：仍然前进，但只走一行，不允许跳行。
  int limit({required int from, required int to, required int nowMs}) {
    if (to <= from) return to;
    final delta = to - from;
    _prune(nowMs);
    if (delta <= 1) return to;
    var used = 0;
    for (final jump in _jumps) {
      used += jump.lines;
    }
    if (used + delta > maxJumpLines) return from + 1;
    _jumps.add(_Jump(nowMs, delta));
    return to;
  }

  /// 清空记录（换稿、手动跳行、重新开始朗读时调用）。
  void reset() => _jumps.clear();

  void _prune(int nowMs) {
    _jumps.removeWhere((jump) => nowMs - jump.atMs >= windowMs);
    // 时间戳若因测试/时钟回拨而不单调，避免记录无限增长。
    if (_jumps.length > 64) _jumps.removeRange(0, _jumps.length - 64);
  }
}

class _Jump {
  const _Jump(this.atMs, this.lines);

  final int atMs;
  final int lines;
}
