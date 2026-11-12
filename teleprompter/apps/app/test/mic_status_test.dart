import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/mic_status.dart';
import 'package:teleprompter/features/reader/voice_health.dart';

void main() {
  MicStatusKind resolve({
    bool voiceOn = true,
    bool ready = true,
    bool paused = false,
    bool appResumed = true,
    bool degraded = false,
    double confidence = 0.8,
    VoiceHealthKind health = VoiceHealthKind.capturing,
    bool gateStalled = false,
  }) =>
      resolveMicStatus(
        voiceOn: voiceOn,
        ready: ready,
        paused: paused,
        appResumed: appResumed,
        degraded: degraded,
        confidence: confidence,
        health: health,
        gateStalled: gateStalled,
      );

  test('后台优先级高于暂停', () {
    expect(
      resolve(paused: true, appResumed: false),
      MicStatusKind.background,
    );
  });

  test('暂停时显示已暂停', () {
    expect(resolve(paused: true), MicStatusKind.paused);
  });

  test('模型未就绪显示加载中', () {
    expect(resolve(ready: false), MicStatusKind.loading);
  });

  test('降级或低置信显示低置信', () {
    expect(resolve(degraded: true), MicStatusKind.lowConfidence);
    expect(resolve(confidence: 0.2), MicStatusKind.lowConfidence);
  });

  test('引擎在解码但没出字显示静音', () {
    expect(
      resolve(confidence: 0, health: VoiceHealthKind.silent),
      MicStatusKind.silent,
    );
  });

  test('采集断流与引擎卡死分别有独立文案，不复用静音', () {
    expect(
      resolve(health: VoiceHealthKind.captureStalled),
      MicStatusKind.captureLost,
    );
    expect(
      resolve(health: VoiceHealthKind.engineStalled),
      MicStatusKind.engineStalled,
    );
  });

  test('有识别文本但锚点不推进显示闸门卡住', () {
    expect(
        resolve(confidence: 0, gateStalled: true), MicStatusKind.gateStalled);
  });

  test('正常收音', () {
    expect(resolve(), MicStatusKind.listening);
  });
}
