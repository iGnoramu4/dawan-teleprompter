import 'voice_health.dart';

/// 语音识别模式的收音状态（阅读页常驻角标）。
enum MicStatusKind {
  /// 模型/识别器加载中。
  loading,

  /// 已就绪但用户尚未开始（初始待机或手动暂停）。
  paused,

  /// 正常收音。
  listening,

  /// 引擎在解码，但一段时间没有识别到有效语音。
  silent,

  /// 置信度低，锚点暂不推进。
  lowConfidence,

  /// 应用切到后台。
  background,

  /// 麦克风采集断流（服务被杀/权限收回/焦点丢失），正在自动重连。
  captureLost,

  /// 有音频分片但没有解码心跳，识别引擎无响应。
  engineStalled,

  /// 有识别文本但锚点不推进（语音与稿件不匹配）。
  gateStalled,
}

/// 根据页面与识别状态解析角标应显示的收音状态。
///
/// 优先级：后台 > 暂停 > 加载 > 采集中断 > 引擎卡死 > 低置信 > 静音 >
/// 闸门卡住 > 正常收音。三个「卡住」原因各有独立文案，不再统一复用静音。
MicStatusKind resolveMicStatus({
  required bool voiceOn,
  required bool ready,
  required bool paused,
  required bool appResumed,
  required bool degraded,
  required double confidence,
  VoiceHealthKind health = VoiceHealthKind.capturing,
  bool gateStalled = false,
}) {
  if (voiceOn && !appResumed) return MicStatusKind.background;
  if (voiceOn && paused) return MicStatusKind.paused;
  if (!ready) return MicStatusKind.loading;
  if (voiceOn && health == VoiceHealthKind.captureStalled) {
    return MicStatusKind.captureLost;
  }
  if (voiceOn && health == VoiceHealthKind.engineStalled) {
    return MicStatusKind.engineStalled;
  }
  if (degraded || (confidence > 0 && confidence < 0.35)) {
    return MicStatusKind.lowConfidence;
  }
  if (voiceOn && health == VoiceHealthKind.silent) return MicStatusKind.silent;
  if (voiceOn && gateStalled) return MicStatusKind.gateStalled;
  return MicStatusKind.listening;
}
