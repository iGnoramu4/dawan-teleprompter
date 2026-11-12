import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

class AudioCaptureException implements Exception {
  AudioCaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 麦克风采集参数（实验面板可切换）。
///
/// 默认值与 0.22.0 的硬编码行为一致，因此不显式配置时行为不变。
class AudioCaptureConfig {
  const AudioCaptureConfig({
    this.preferVoiceRecognition = true,
    this.autoGain = true,
    this.echoCancel = true,
    this.noiseSuppress = true,
    this.bufferMs = 0,
  });

  /// 默认配置（= 0.22.0 行为）。
  static const AudioCaptureConfig defaults = AudioCaptureConfig();

  /// true = `voiceRecognition` 音源，false = 普通 `mic`。
  final bool preferVoiceRecognition;

  /// 自动增益（AGC）。
  final bool autoGain;

  /// 回声消除（AEC）。
  final bool echoCancel;

  /// 噪声抑制（NS）。
  final bool noiseSuppress;

  /// 再分片目标时长（毫秒）；0 = 保持插件原始分片。
  final int bufferMs;

  AudioCaptureConfig copyWith({
    bool? preferVoiceRecognition,
    bool? autoGain,
    bool? echoCancel,
    bool? noiseSuppress,
    int? bufferMs,
  }) {
    return AudioCaptureConfig(
      preferVoiceRecognition:
          preferVoiceRecognition ?? this.preferVoiceRecognition,
      autoGain: autoGain ?? this.autoGain,
      echoCancel: echoCancel ?? this.echoCancel,
      noiseSuppress: noiseSuppress ?? this.noiseSuppress,
      bufferMs: bufferMs ?? this.bufferMs,
    );
  }

  Map<String, Object?> toJson() => {
        'audioSource': preferVoiceRecognition ? 'voiceRecognition' : 'mic',
        'autoGain': autoGain,
        'echoCancel': echoCancel,
        'noiseSuppress': noiseSuppress,
        'bufferMs': bufferMs,
      };

  @override
  String toString() =>
      'AudioCaptureConfig(source: ${preferVoiceRecognition ? 'voiceRecognition' : 'mic'}, '
      'agc: $autoGain, aec: $echoCancel, ns: $noiseSuppress, '
      'bufferMs: $bufferMs)';
}

/// 麦克风采集：16 kHz / 16 bit / mono PCM，输出归一化 Float32 分片。
class AudioCapture {
  AudioCapture({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  bool _recording = false;

  bool get isRecording => _recording;

  Future<Stream<Float32List>> start({
    AudioCaptureConfig config = AudioCaptureConfig.defaults,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw AudioCaptureException('麦克风权限未授予');
    }

    final recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: config.autoGain,
      echoCancel: config.echoCancel,
      noiseSuppress: config.noiseSuppress,
      androidConfig: AndroidRecordConfig(
        audioSource: config.preferVoiceRecognition
            ? AndroidAudioSource.voiceRecognition
            : AndroidAudioSource.mic,
        audioManagerMode: AudioManagerMode.modeInCommunication,
      ),
    );

    final stream = await _recorder.startStream(recordConfig);
    _recording = true;
    final samples = stream.map(_pcm16ToFloat32);
    return _chunk(samples, config.bufferMs * 16);
  }

  Future<void> stop() async {
    if (!_recording) return;
    _recording = false;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  /// 把插件分片重新聚合到 [targetSamples]（16 kHz 下 1 ms = 16 个采样）。
  ///
  /// 0 表示不分片，直接透传插件原始分片。
  static Stream<Float32List> _chunk(
    Stream<Float32List> source,
    int targetSamples,
  ) {
    if (targetSamples <= 0) return source;
    final controller = StreamController<Float32List>();
    final buffer = Float32List(targetSamples);
    var fill = 0;
    StreamSubscription<Float32List>? subscription;

    controller.onListen = () {
      subscription = source.listen(
        (chunk) {
          var offset = 0;
          while (offset < chunk.length) {
            final take = math.min(targetSamples - fill, chunk.length - offset);
            buffer.setRange(fill, fill + take, chunk, offset);
            fill += take;
            offset += take;
            if (fill == targetSamples) {
              controller.add(Float32List.fromList(buffer));
              fill = 0;
            }
          }
        },
        onError: controller.addError,
        onDone: () {
          if (fill > 0) {
            controller.add(Float32List.sublistView(buffer, 0, fill));
          }
          controller.close();
        },
      );
    };
    controller.onPause = () => subscription?.pause();
    controller.onResume = () => subscription?.resume();
    controller.onCancel = () async {
      await subscription?.cancel();
      subscription = null;
    };
    return controller.stream;
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final out = Float32List(count);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}
