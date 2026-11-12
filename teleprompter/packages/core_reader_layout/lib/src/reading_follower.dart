import 'dart:math' as math;

/// 提词滚动位置控制器。
///
/// 两条路径共用同一个连续像素位置，但驱动方式不同：
/// - 语音跟随：[snapTo] 逐行推进，每行用非线性缓动（easeOutCubic）
///   把目标行吸到阅读带（下划线）位置，单段最多 1 个视觉行；
///   同一段连续吸附里第一行用 [snapDuration]（500 ms），后续行用
///   [snapCatchUpDuration]（160 ms），避免跨 2–3 行时总时长线性累加；
/// - 触控：[nudge] / [fling] 直接改连续像素位置，不做整行量化、
///   不做松手吸附，也不会被语音吸附拽回（冻结期间吸附完全停止）。
class ReadingFollower {
  /// 创建跟随器。
  ReadingFollower({
    double position = 0,
    this.maxSpeed = 2400,
    this.settleEpsilon = 0.5,
    this.jumpFade = const Duration(milliseconds: 120),
    this.jumpRows = 8,
    this.flingTau = const Duration(milliseconds: 450),
    this.snapDuration = const Duration(milliseconds: 500),
    this.snapCatchUpDuration = const Duration(milliseconds: 160),
  })  : _position = position,
        _target = position;

  /// 惯性速度上限（px/s）。
  double maxSpeed;

  /// 到位判定阈值（px）。
  double settleEpsilon;

  /// 远距离落位后的淡入时长。
  Duration jumpFade;

  /// 超过该行数直接落位（不逐行吸附）。
  double jumpRows;

  /// 手动松手后惯性的速度衰减时间常数。
  Duration flingTau;

  /// 语音吸附第一行的时长（单行事件完整走完这个节奏）。
  Duration snapDuration;

  /// 同一段连续吸附中从第 2 行起的每行时长。
  ///
  /// 语音一次跨 2–3 行时，若每行都吃满 [snapDuration]，总时长会到
  /// 1–1.5 s，读快时越落越远；追加行改用更短的追赶时长，单段仍是
  /// 一个视觉行、仍是 easeOutCubic 且落位即停。
  Duration snapCatchUpDuration;

  /// 允许的最小滚动偏移。
  double minScroll = 0;

  /// 允许的最大滚动偏移。
  double maxScroll = double.infinity;

  /// 视觉行行距（px），吸附分段以此为最大步长。
  double pitch = 1;

  /// 是否冻结（暂停/拖拽）。冻结会立即取消语音吸附。
  bool frozen = false;

  double _position;
  double _target;

  bool _fading = false;
  double _fadeOpacity = 1;
  int _restFrames = 0;
  double _flingVelocity = 0;

  bool _snapping = false;
  int _snapSegments = 0;
  double _snapGoal = 0;
  double _snapFrom = 0;
  double _snapSegmentTo = 0;
  double _snapSegmentSeconds = 0;
  double _snapElapsed = 0;

  /// 当前滚动偏移（px）。
  double get position => _position;

  /// 当前目标偏移（px）。
  double get target => _target;

  /// 内容不透明度（跳读淡入用，1 = 完全显示）。
  double get fadeOpacity => _fadeOpacity;

  /// 是否处于跳读淡入。
  bool get fading => _fading;

  /// 是否正在做语音吸附。
  bool get snapping => _snapping;

  /// 已经完成的吸附分段数；0 表示下一段是第一行。
  int get snapSegments => _snapSegments;

  /// 是否已经静止（连续 3 帧无位移）。
  bool get atRest => _restFrames >= 3;

  /// 是否还在惯性滑动。
  bool get flinging => _flingVelocity.abs() > 0;

  /// 由平滑度（4–12）映射吸附时长：越大越干脆。
  ///
  /// 4 → 550 ms/行，8 → 500 ms/行，12 → 450 ms/行。
  static Duration snapDurationFromSmoothness(double smoothness) {
    final ms = (600 - 12.5 * smoothness).clamp(450.0, 550.0);
    return Duration(milliseconds: ms.round());
  }

  /// 配置滚动边界与行距，并把当前位置与目标夹回边界内。
  void configureBounds({
    required double min,
    required double max,
    double? pitch,
  }) {
    minScroll = min;
    maxScroll = max;
    if (pitch != null) {
      this.pitch = math.max(1.0, pitch);
    }
    _position = _clamp(_position);
    _snapGoal = _clamp(_snapGoal);
    _snapSegmentTo = _clamp(_snapSegmentTo);
    _target = _snapping ? _snapGoal : _position;
  }

  /// 语音跟随目标：把 [y] 吸附到阅读带位置。
  ///
  /// 一次最多移动 1 个视觉行，跨多行时排队逐行吸附；每段都是
  /// easeOutCubic（前快后慢），段与段之间速度为 0，落位后停稳。
  /// 冻结期间（识别暂停、拖拽中）调用会被忽略。
  void snapTo(double y) {
    if (frozen) return;
    final clamped = _clamp(y);
    if ((_snapGoal - clamped).abs() <= settleEpsilon &&
        (_position - clamped).abs() <= settleEpsilon) {
      return;
    }
    // 远距离（跳段/遥控）不逐行穿越，直接落位并淡入。
    if ((clamped - _position).abs() > jumpRows * pitch) {
      jumpToWithFade(clamped);
      return;
    }

    _flingVelocity = 0;
    _fading = false;
    _fadeOpacity = 1;
    _snapGoal = clamped;
    _target = clamped;
    if (_snapping) return;
    _startSnapSegment();
  }

  /// 冻结在当前位置（暂停/拖拽开始），取消正在进行的吸附。
  void freeze() {
    frozen = true;
    _target = _position;
    _flingVelocity = 0;
    _cancelSnap();
    _restFrames = 0;
  }

  /// 解除冻结；目标保持当前位置，等待下一次语音吸附。
  void unfreeze() {
    frozen = false;
  }

  /// 手动拖拽：直接改位置并接管目标，取消吸附。
  void nudge(double deltaY) {
    _position = _clamp(_position + deltaY);
    _target = _position;
    _flingVelocity = 0;
    _cancelSnap();
    _fading = false;
    _fadeOpacity = 1;
    _restFrames = 0;
  }

  /// 手动匀速滚动（行/秒）。
  void advanceManual(double dt, {required double linesPerSecond}) {
    nudge(linesPerSecond * pitch * dt);
  }

  /// 松手后的惯性：按 [velocity]（px/s）继续滑动并按 [flingTau] 衰减。
  ///
  /// 不改变目标位置，也不做整行吸附；滑动中可直接被下一次拖拽或
  /// 语音吸附接管。
  void fling(double velocity) {
    frozen = false;
    _flingVelocity = velocity.clamp(-maxSpeed * 2, maxSpeed * 2).toDouble();
    _target = _position;
    _cancelSnap();
    _fading = false;
    _fadeOpacity = 1;
    _restFrames = 0;
  }

  /// 手动跳转（无动画）。
  void jumpTo(double y) {
    _position = _clamp(y);
    _target = _position;
    _flingVelocity = 0;
    _cancelSnap();
    _fading = false;
    _fadeOpacity = 1;
    _restFrames = 0;
  }

  /// 手动跳转并淡入（跳段/篇首篇尾/遥控 jump）。
  void jumpToWithFade(double y) {
    _position = _clamp(y);
    _target = _position;
    _flingVelocity = 0;
    _cancelSnap();
    _startFade();
  }

  /// 推进一帧（[dt] 秒）。
  void step(double dt) {
    if (dt <= 0) return;

    if (_fading) {
      _fadeOpacity += dt / math.max(0.001, jumpFade.inMicroseconds / 1e6);
      if (_fadeOpacity >= 1) {
        _fadeOpacity = 1;
        _fading = false;
      }
    }

    if (frozen) {
      _cancelSnap();
      _restFrames = 3;
      return;
    }

    if (_snapping) {
      _advanceSnap(dt);
      return;
    }

    if (_flingVelocity.abs() > 0.5) {
      final next = _position + _flingVelocity * dt;
      final clamped = _clamp(next);
      if (clamped != next) {
        // 触边：落到边界而不是停在上一帧，避免差一帧的「没滑到位」。
        _position = clamped;
        _flingVelocity = 0;
      } else {
        _position = clamped;
        _flingVelocity *= math.exp(
          -dt / math.max(0.001, flingTau.inMicroseconds / 1e6),
        );
        if (_flingVelocity.abs() < 20) _flingVelocity = 0;
      }
      _target = _position;
      _restFrames = 0;
      if (_flingVelocity == 0) _restFrames = 1;
      return;
    }

    _flingVelocity = 0;
    _target = _position;
    _restFrames += 1;
  }

  void _advanceSnap(double dt) {
    _snapElapsed += dt;
    final total = math.max(0.001, _snapSegmentSeconds);
    final t = (_snapElapsed / total).clamp(0.0, 1.0);
    // easeOutCubic：起步快、贴线慢，末速度为 0，落位没有顿挫。
    final eased = 1 - math.pow(1 - t, 3).toDouble();
    _position = _clamp(_snapFrom + (_snapSegmentTo - _snapFrom) * eased);
    _restFrames = 0;
    if (t < 1) return;

    _position = _clamp(_snapSegmentTo);
    if ((_snapGoal - _position).abs() <= settleEpsilon) {
      _position = _snapGoal;
      _target = _position;
      _snapping = false;
      _snapSegments = 0;
      _snapElapsed = 0;
      _restFrames = 1;
      return;
    }
    _startSnapSegment();
  }

  /// 开始下一段吸附：单段位移不超过 1 个视觉行。
  ///
  /// 第一段走完整的 [snapDuration]（单行事件的 500 ms 节奏），
  /// 同一段连续吸附的追加行走 [snapCatchUpDuration]，避免跨 2–3 行时
  /// 总时长线性累加到 1–1.5 s。
  void _startSnapSegment() {
    if (frozen) {
      _cancelSnap();
      return;
    }
    final delta = _snapGoal - _position;
    if (delta.abs() <= settleEpsilon) {
      _position = _snapGoal;
      _target = _position;
      _snapping = false;
      _snapSegments = 0;
      return;
    }
    final maxStep = math.max(1.0, pitch);
    final end = _position + delta.clamp(-maxStep, maxStep);
    final rows = (end - _position).abs() / math.max(1.0, pitch);
    final base = _snapSegments == 0 ? snapDuration : snapCatchUpDuration;
    _snapFrom = _position;
    _snapSegmentTo = end;
    _snapSegmentSeconds = base.inMicroseconds / 1e6 * rows.clamp(0.35, 1.0);
    _snapElapsed = 0;
    _snapping = true;
    _snapSegments += 1;
    _restFrames = 0;
  }

  void _cancelSnap() {
    _snapping = false;
    _snapSegments = 0;
    _snapElapsed = 0;
    _snapGoal = _position;
    _snapSegmentTo = _position;
  }

  void _startFade() {
    _fading = true;
    _fadeOpacity = 0.35;
    _restFrames = 0;
  }

  double _clamp(double y) {
    if (y < minScroll) return minScroll;
    if (y > maxScroll) return maxScroll;
    return y;
  }
}
