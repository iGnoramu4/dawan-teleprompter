import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/voice_health.dart';

void main() {
  final t0 = DateTime(2026, 11, 10, 12);

  test('三类卡住原因必须分开判定', () {
    // 采集断流：有会话、没有分片。
    final capture = VoiceHealthMonitor()..start(t0);
    expect(
      capture.evaluate(t0.add(const Duration(seconds: 3))).kind,
      VoiceHealthKind.captureStalled,
    );

    // 引擎无帧：分片持续到达，但没有解码心跳。
    final engine = VoiceHealthMonitor()..start(t0);
    for (var ms = 0; ms <= 4000; ms += 200) {
      engine.onChunk(t0.add(Duration(milliseconds: ms)));
    }
    expect(
      engine.evaluate(t0.add(const Duration(seconds: 4))).kind,
      VoiceHealthKind.engineStalled,
    );

    // 静音：分片与心跳都正常，只是没出字。
    final silent = VoiceHealthMonitor()..start(t0);
    for (var ms = 0; ms <= 5000; ms += 200) {
      final now = t0.add(Duration(milliseconds: ms));
      silent.onChunk(now);
      silent.onTick(now);
    }
    expect(
      silent.evaluate(t0.add(const Duration(seconds: 5))).kind,
      VoiceHealthKind.silent,
    );
  });

  test('分片、心跳、文本都在更新时判定为正常收音', () {
    final monitor = VoiceHealthMonitor()..start(t0);
    final now = t0.add(const Duration(seconds: 2));
    monitor
      ..onChunk(now)
      ..onTick(now)
      ..onText(now);
    final health = monitor.evaluate(now);
    expect(health.kind, VoiceHealthKind.capturing);
    expect(health.chunkCount, 1);
    expect(health.tickCount, 1);
    expect(health.textCount, 1);
  });

  test('采集流关闭立即判定断流，不等阈值', () {
    final monitor = VoiceHealthMonitor()
      ..start(t0)
      ..onChunk(t0)
      ..onCaptureClosed();
    expect(
      monitor.evaluate(t0.add(const Duration(milliseconds: 300))).kind,
      VoiceHealthKind.captureStalled,
    );
  });

  test('重开采集后恢复为正常，并累计重连次数', () {
    final monitor = VoiceHealthMonitor()..start(t0);
    final stalledAt = t0.add(const Duration(seconds: 4));
    expect(monitor.evaluate(stalledAt).kind, VoiceHealthKind.captureStalled);

    final restartedAt = t0.add(const Duration(seconds: 5));
    monitor.onCaptureRestarted(restartedAt);
    // 重连后用户马上开口：已恢复收音（重连前静音超过阈值不影响判定）。
    monitor.onText(restartedAt);
    final health = monitor.evaluate(restartedAt);
    expect(health.kind, VoiceHealthKind.capturing);
    expect(health.captureRestarts, 1);
    expect(health.toLog()['restarts'], 1);
  });

  test('会话未开始时为 idle', () {
    expect(VoiceHealthMonitor().evaluate(t0).kind, VoiceHealthKind.idle);
  });
}
