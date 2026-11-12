import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:asr_kit/asr_kit.dart';
import 'package:core_recording/core_recording.dart';
import 'package:data_store/data_store.dart';

import 'recording_store.dart';
import 'wav_writer.dart';

typedef AnchorReader = int Function();

/// 行内字符偏移读取器（整篇连续文本的锚点）。
typedef CharReader = int Function();

/// E8-1 录制控制器：音频写 WAV，10 Hz 采样时间轴，停止后落库。
///
/// 麦克风所有权：默认自己打开麦克风；若语音跟随已在收音，由阅读页把 PCM
/// 分片转发进 [feed]，避免同时打开两路麦克风（§10.6）。
class RecordingController {
  RecordingController({
    required this.repository,
    required this.store,
    required this.scriptId,
    required this.readAnchor,
    this.readChar,
    this.tickInterval = const Duration(milliseconds: 100),
    int Function()? clock,
    this.onError,
  }) : _clock = clock;

  final ScriptRepository repository;
  final RecordingStore store;
  final String scriptId;
  final AnchorReader readAnchor;

  /// 当前行内字符偏移；未提供时按 0 采样（行级时间轴）。
  final CharReader? readChar;
  final Duration tickInterval;
  final void Function(String message)? onError;

  final int Function()? _clock;

  AudioCapture? _mic;
  bool _recording = false;
  String? _id;
  String? _path;
  PcmWavWriter? _writer;
  TimelineBuilder? _timeline;
  Timer? _timer;
  StreamSubscription<Float32List>? _subscription;
  Future<void> _writeChain = Future<void>.value();
  Stopwatch? _watch;

  bool get isRecording => _recording;

  String? get audioPath => _path;

  int get elapsedMs => _clock?.call() ?? _watch?.elapsedMilliseconds ?? 0;

  int get sampleCount => _timeline?.samples.length ?? 0;

  /// 开始录制。[useMic] 为 false 时等待 [feed] 推入 PCM 分片。
  Future<void> start({bool useMic = true}) async {
    if (_recording) return;
    final id = RecordingStore.newId();
    final path = await store.newAudioPath(id);
    final writer = await PcmWavWriter.create(path);

    _id = id;
    _path = path;
    _writer = writer;
    _timeline = TimelineBuilder(scriptId: scriptId);
    _watch = Stopwatch()..start();

    try {
      if (useMic) {
        final mic = AudioCapture();
        final stream = await mic.start();
        _mic = mic;
        _subscription = stream.listen(
          _onChunk,
          onError: _handleAudioError,
        );
      }
      _recording = true;
      _timeline!.sample(0, readAnchor(), char: readChar?.call() ?? 0);
      _timer = Timer.periodic(tickInterval, (_) => _sampleNow());
    } catch (error) {
      await writer.abort();
      _clear();
      rethrow;
    }
  }

  /// 语音跟随转发来的 PCM 分片（[start] 时 `useMic: false`）。
  void feed(Float32List chunk) => _onChunk(chunk);

  void _onChunk(Float32List chunk) {
    final writer = _writer;
    if (writer == null) return;
    _writeChain = _writeChain.then((_) => writer.write(chunk)).catchError(
          (Object error) => _handleAudioError(error),
        );
  }

  void _handleAudioError(Object error) {
    onError?.call(error.toString());
  }

  void _sampleNow() {
    if (!_recording) return;
    _timeline?.sample(elapsedMs, readAnchor(), char: readChar?.call() ?? 0);
  }

  /// 停止并落库。
  Future<RecordingEntry?> stop() async {
    if (!_recording) return null;
    _recording = false;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      await mic.stop();
      await mic.dispose();
    }

    final writer = _writer;
    final timeline = _timeline;
    final id = _id;
    final path = _path;
    if (writer == null || timeline == null || id == null || path == null) {
      _clear();
      return null;
    }

    final duration = elapsedMs;
    timeline.sample(duration, readAnchor(), char: readChar?.call() ?? 0);
    await _writeChain;
    await writer.close();

    int size = 0;
    try {
      size = await File(path).length();
    } catch (_) {
      size = writer.dataBytes;
    }

    final entry = RecordingEntry(
      id: id,
      scriptId: scriptId,
      path: path,
      durationMs: duration,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      sizeBytes: size,
      timelineJson: timeline.finish(duration).encode(),
    );
    await repository.insertRecording(entry);
    _clear();
    return entry;
  }

  /// 放弃录制：停止采集并删除半成品音频。
  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      await mic.stop();
      await mic.dispose();
    }
    await _writeChain;
    final writer = _writer;
    _clear();
    await writer?.abort();
  }

  Future<void> dispose() async {
    if (_recording) await cancel();
  }

  void _clear() {
    _id = null;
    _path = null;
    _writer = null;
    _timeline = null;
    _watch = null;
    _writeChain = Future<void>.value();
  }
}
