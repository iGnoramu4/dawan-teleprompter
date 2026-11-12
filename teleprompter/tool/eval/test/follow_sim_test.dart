import 'package:test/test.dart';

import '../lib/follow_sim.dart';

/// D1/D2 回归：段尾替换不抢行、跨行后仍能继续推进。
void main() {
  const lines = [
    '这个功能依赖 Flutter 的插件体系，底层是 sherpa-onnx。',
    '我们把音频流交给 SDK，由它返回 JSON 格式的结果。',
    '前端的 prompt 需要单独配置，不能写死在代码里。',
  ];

  test('段尾未命中的替换不把锚点钉在行尾', () {
    final sim = FollowSimulator(lines: lines);
    sim.onAsr(
      audioMs: 5220,
      text: '这个功能依赖觉得插件体系底层是声音',
      isFinal: false,
    );
    expect(sim.line, 0);
    expect(sim.charOffset, 23);
  });

  test('提前跨行后仍能在行内推进并继续进入下一行', () {
    final sim = FollowSimulator(lines: lines);

    // 首行还没读完时，识别已经稳定命中第二行开头：允许提前跨行。
    sim.onAsr(audioMs: 6000, text: '我们把音频流交给', isFinal: false);
    expect(sim.line, 1);
    final afterStep = sim.charOffset;

    // 同一行继续说话：段内字符必须继续前进，不能卡在跨行落点。
    sim.onAsr(
      audioMs: 9400,
      text: '我们把音频流交给 SDK 由它返回',
      isFinal: false,
    );
    expect(sim.line, 1);
    expect(sim.charOffset, greaterThan(afterStep));

    // 第三行开始后应继续跨行。
    sim.onAsr(audioMs: 13800, text: '前端的 prompt 需要单独配置不能写死', isFinal: false);
    expect(sim.line, 2);
  });

  test('行级覆盖达标但未跨行时不滚行（静音守线）', () {
    final sim = FollowSimulator(lines: lines);
    sim.onAsr(audioMs: 1000, text: '这个功能依赖 Flutter 的插件体系底层是', isFinal: false);
    sim.onAsr(audioMs: 2000, text: '这个功能依赖 Flutter 的插件体系底层是', isFinal: true);
    expect(sim.line, 0);
    // 只有行内字符推进事件，没有跨行事件。
    expect(sim.events.every((e) => e.line == 0), isTrue);
  });

  test('行级覆盖达标后，下一条跨行读音直接放行', () {
    final sim = FollowSimulator(lines: lines);
    sim.onAsr(audioMs: 1000, text: '这个功能依赖 Flutter 的插件体系底层是', isFinal: false);
    expect(sim.line, 0);
    sim.onAsr(audioMs: 2600, text: '我们把音频流交给', isFinal: false);
    expect(sim.line, 1);
    expect(sim.events.last.reason, 'line_coverage');
  });

  test('连续多次 3 行跳不累积（10 秒预算）', () {
    const jumps = [
      '甲乙丙丁戊己',
      '庚辛壬癸子丑',
      '寅卯辰巳午未',
      '申酉戌亥天地',
      '日月星辰宇宙',
      '春夏秋冬风雪',
      '东南西北山川',
      '江河湖海波涛',
      '金木水火土石',
      '赤橙黄绿青蓝',
    ];
    final sim = FollowSimulator(lines: jumps);
    // 每 3 秒一条高置信「前进 3 行」的证据：单次都合法，累计必须被拦。
    sim.onAsr(audioMs: 1000, text: jumps[3], isFinal: true);
    sim.onAsr(audioMs: 4000, text: jumps[6], isFinal: true);
    sim.onAsr(audioMs: 7000, text: jumps[9], isFinal: true);

    expect(sim.line, 5, reason: '10 秒内跳行累计 3 行后只允许逐行，不能冲到 9');
    final crossLine = sim.events.where((e) => e.line > 0).toList();
    var jumped = 0;
    var previous = 0;
    for (final event in crossLine) {
      final delta = event.line - previous;
      if (delta > 1) jumped += delta;
      previous = event.line;
    }
    expect(jumped, lessThanOrEqualTo(3));
  });
}
