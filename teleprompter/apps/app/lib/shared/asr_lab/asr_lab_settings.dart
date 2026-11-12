import 'dart:convert';

import 'package:asr_kit/asr_kit.dart';
import 'package:data_store/data_store.dart';

/// 实验配置（开发面板）：端点与音频采集参数。
///
/// 默认值 = 0.22.0 的现有行为，未改过面板时对普通用户无影响。
/// 存在 `app_settings` 的 `asr_lab` 键，只在开发/实验面板里暴露。
const String asrLabKey = 'asr_lab';

class AsrLabSettings {
  const AsrLabSettings({
    this.rule1MinTrailingSilence = 2.4,
    this.rule2MinTrailingSilence = 1.2,
    this.preferVoiceRecognition = true,
    this.autoGain = true,
    this.echoCancel = true,
    this.noiseSuppress = true,
    this.bufferMs = 0,
  });

  /// 与 0.22.0 硬编码参数一致。
  static const AsrLabSettings defaults = AsrLabSettings();

  /// 端点规则 1：有文本后静音多久断句（秒）。
  final double rule1MinTrailingSilence;

  /// 端点规则 2：纯静音多久断句（秒）。
  final double rule2MinTrailingSilence;

  /// true = `voiceRecognition` 音源，false = 普通 `mic`。
  final bool preferVoiceRecognition;
  final bool autoGain;
  final bool echoCancel;
  final bool noiseSuppress;

  /// 再分片目标时长（毫秒）；0 = 插件原始分片。
  final int bufferMs;

  AsrTuning toAsrTuning() => AsrTuning(
        rule1MinTrailingSilence: rule1MinTrailingSilence,
        rule2MinTrailingSilence: rule2MinTrailingSilence,
      );

  AudioCaptureConfig toAudioConfig() => AudioCaptureConfig(
        preferVoiceRecognition: preferVoiceRecognition,
        autoGain: autoGain,
        echoCancel: echoCancel,
        noiseSuppress: noiseSuppress,
        bufferMs: bufferMs,
      );

  AsrLabSettings copyWith({
    double? rule1MinTrailingSilence,
    double? rule2MinTrailingSilence,
    bool? preferVoiceRecognition,
    bool? autoGain,
    bool? echoCancel,
    bool? noiseSuppress,
    int? bufferMs,
  }) {
    return AsrLabSettings(
      rule1MinTrailingSilence:
          rule1MinTrailingSilence ?? this.rule1MinTrailingSilence,
      rule2MinTrailingSilence:
          rule2MinTrailingSilence ?? this.rule2MinTrailingSilence,
      preferVoiceRecognition:
          preferVoiceRecognition ?? this.preferVoiceRecognition,
      autoGain: autoGain ?? this.autoGain,
      echoCancel: echoCancel ?? this.echoCancel,
      noiseSuppress: noiseSuppress ?? this.noiseSuppress,
      bufferMs: bufferMs ?? this.bufferMs,
    );
  }

  /// 参数归一化：磁盘内容与旧版本都可能越界，统一收口。
  AsrLabSettings normalized() => copyWith(
        rule1MinTrailingSilence:
            rule1MinTrailingSilence.clamp(0.4, 3.0).toDouble(),
        rule2MinTrailingSilence:
            rule2MinTrailingSilence.clamp(0.4, 2.4).toDouble(),
        bufferMs: bufferMs.clamp(0, 1000),
      );

  Map<String, Object?> toJson() => {
        'rule1MinTrailingSilence': rule1MinTrailingSilence,
        'rule2MinTrailingSilence': rule2MinTrailingSilence,
        'audioSource': preferVoiceRecognition ? 'voiceRecognition' : 'mic',
        'autoGain': autoGain,
        'echoCancel': echoCancel,
        'noiseSuppress': noiseSuppress,
        'bufferMs': bufferMs,
      };

  factory AsrLabSettings.fromJson(Map<String, Object?> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final source = json['audioSource'];
    final voiceRecognition =
        source is String ? source == 'voiceRecognition' : true;

    return AsrLabSettings(
      rule1MinTrailingSilence: readDouble('rule1MinTrailingSilence', 2.4),
      rule2MinTrailingSilence: readDouble('rule2MinTrailingSilence', 1.2),
      preferVoiceRecognition: voiceRecognition,
      autoGain: readBool('autoGain', true),
      echoCancel: readBool('echoCancel', true),
      noiseSuppress: readBool('noiseSuppress', true),
      bufferMs: (json['bufferMs'] as num?)?.toInt() ?? 0,
    ).normalized();
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析 [toJsonString] 写出的内容；非法内容抛 [FormatException]。
  static AsrLabSettings fromRaw(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return AsrLabSettings.fromJson(decoded);
    }
    throw const FormatException('asr lab settings is not a JSON object');
  }

  @override
  String toString() => 'AsrLabSettings(rule1: $rule1MinTrailingSilence, '
      'rule2: $rule2MinTrailingSilence, '
      'source: ${preferVoiceRecognition ? 'voiceRecognition' : 'mic'}, '
      'agc: $autoGain, aec: $echoCancel, ns: $noiseSuppress, '
      'bufferMs: $bufferMs)';
}

Future<AsrLabSettings> loadAsrLabSettings(ScriptRepository repository) async {
  final raw = await repository.getSetting(asrLabKey);
  if (raw == null || raw.isEmpty) return AsrLabSettings.defaults;
  try {
    return AsrLabSettings.fromRaw(raw);
  } catch (_) {
    return AsrLabSettings.defaults;
  }
}

Future<void> saveAsrLabSettings(
  ScriptRepository repository,
  AsrLabSettings settings,
) async {
  await repository.setSetting(asrLabKey, settings.toJsonString());
}
