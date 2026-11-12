import 'dart:math' as math;

/// 临界阻尼弹簧滚动规划器（§5.6）。
///
/// 坐标约定：`position` 是内容滚动偏移（px），`target` 是让锚点行停在视口
/// 35% 高度所需的偏移。渲染层只做 `Transform.translate(0, -position)`，
/// 不触发文本重新布局。
class ScrollPlanner {
  /// 创建规划器。
  ScrollPlanner({
    this.omega = 8.0,
    this.zeta = 0.9,
    this.maxSpeed = 600,
    this.catchUpSpeed = 1200,
    this.targetDebounce = const Duration(milliseconds: 80),
    this.readAheadRatio = 0.35,
  });

  /// 弹簧角频率（rad/s），由"平滑度"参数映射到 4–12。
  double omega;

  /// 阻尼比，接近 1 避免过冲。
  double zeta;

  /// 常态最大速度（px/s）。
  double maxSpeed;

  /// 跳读追赶时的最大速度（px/s）。
  double catchUpSpeed;

  /// 目标去抖时长，避免识别抖动导致目标频繁跳变。
  Duration targetDebounce;

  /// 锚点行位于视口高度的比例（默认 35%）。
  double readAheadRatio;

  /// 当前内容滚动偏移（px）。
  double position = 0;

  /// 当前速度（px/s）。
  double velocity = 0;

  /// 允许的最小滚动偏移。
  double minScroll = 0;

  /// 允许的最大滚动偏移。
  double maxScroll = double.infinity;

  /// 是否冻结（停顿停住）。
  bool frozen = false;

  /// 是否处于跳读快速追赶。
  bool fastCatchUp = false;

  double _target = 0;
  double? _pendingTarget;
  double _pendingElapsed = 0;
  double _lineHeight = 1;

  /// 当前目标偏移。
  double get target => _target;

  /// 配置滚动边界，并把当前位置与目标夹回边界内。
  void configureBounds({required double min, required double max}) {
    minScroll = min;
    maxScroll = max;
    position = _clamp(position);
    _target = _clamp(_target);
  }

  /// 手动模式/测试用：设置估算行高（默认 1 px）。
  void setLineHeight(double height) {
    _lineHeight = math.max(1.0, height);
  }

  /// 更新语音跟随的目标位置。
  ///
  /// [lineHeight] 用于死区（0.5 行）与跳读距离（5 行）判定。
  /// [immediate] 用于手动跳转/初始化，绕过 80 ms 去抖。
  void setTarget(
    double y, {
    required double lineHeight,
    bool immediate = false,
  }) {
    _lineHeight = math.max(1.0, lineHeight);
    final clamped = _clamp(y);
    if (frozen && !immediate) return;

    final delta = (clamped - _target).abs();
    if (delta < _lineHeight * 0.5) return;

    if (delta > _lineHeight * 5) {
      fastCatchUp = true;
    }

    if (immediate || delta > _lineHeight * 5) {
      _commitTarget(clamped);
      return;
    }

    _pendingTarget = clamped;
    _pendingElapsed = 0;
  }

  /// 冻结在当前位置（停顿停住）。
  void freeze() {
    frozen = true;
    _target = position;
    velocity = 0;
    _pendingTarget = null;
  }

  /// 解除冻结；目标保持当前位置，等待下一次跟随更新。
  void unfreeze() {
    frozen = false;
  }

  /// 手动拖拽/滚轮：直接改位置并接管目标。
  void nudge(double deltaY) {
    position = _clamp(position + deltaY);
    _target = position;
    velocity = 0;
    _pendingTarget = null;
    fastCatchUp = false;
  }

  /// 手动匀速滚动 [linesPerSecond] 行/秒。
  void advanceManual(double dt, {required double linesPerSecond}) {
    final delta = linesPerSecond * _lineHeight * dt;
    nudge(delta);
  }

  /// 手动跳转到指定偏移（不带弹簧动画）。
  void jumpTo(double y) {
    position = _clamp(y);
    _target = position;
    velocity = 0;
    _pendingTarget = null;
    fastCatchUp = false;
  }

  /// 推进一帧（[dt] 秒），先处理目标去抖再积分弹簧。
  void step(double dt) {
    if (dt <= 0) return;

    if (_pendingTarget != null) {
      _pendingElapsed += dt;
      if (_pendingElapsed >= targetDebounce.inMilliseconds / 1000.0) {
        _commitTarget(_pendingTarget!);
        _pendingTarget = null;
      }
    }

    if (frozen) {
      velocity = 0;
      return;
    }

    final limit = fastCatchUp ? catchUpSpeed : maxSpeed;
    final accel =
        -omega * omega * (position - _target) - 2 * zeta * omega * velocity;
    velocity = (velocity + accel * dt).clamp(-limit, limit);
    position = _clamp(position + velocity * dt);

    if ((position - _target).abs() < 0.05 && velocity.abs() < 0.5) {
      position = _target;
      velocity = 0;
      if ((position - _target).abs() < _lineHeight) fastCatchUp = false;
    }
    if (fastCatchUp && (position - _target).abs() < _lineHeight * 1.0) {
      fastCatchUp = false;
    }
  }

  void _commitTarget(double y) {
    _target = _clamp(y);
    if ((_target - position).abs() > _lineHeight * 5) {
      fastCatchUp = true;
    }
  }

  double _clamp(double y) {
    if (y < minScroll) return minScroll;
    if (y > maxScroll) return maxScroll;
    return y;
  }
}
