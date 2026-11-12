import 'dart:async';

import 'package:core_recording/core_recording.dart';
import 'package:data_store/data_store.dart';

import 'replay_audio.dart';

/// E8-2 复盘控制器：音频位置 → 时间轴插值 → 台本行号。
class ReplayController {
  ReplayController({
    required this.entry,
    required this.timeline,
    ReplayAudio? audio,
    this.onAnchor,
    this.onPosition,
    this.onPlayingChanged,
    this.onError,
  }) : _audio = audio ?? JustAudioReplayAudio();

  final RecordingEntry entry;
  final RecordingTimeline timeline;
  final void Function(int line, int charOffset)? onAnchor;
  final void Function(Duration position)? onPosition;
  final void Function(bool playing)? onPlayingChanged;
  final void Function(String message)? onError;

  final ReplayAudio _audio;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  Duration _position = Duration.zero;
  bool _playing = false;
  double _speed = 1;
  bool _disposed = false;

  Duration get position => _position;

  bool get isPlaying => _playing;

  double get speed => _speed;

  int get durationMs => entry.durationMs;

  static const List<double> speeds = [0.5, 1, 1.5, 2];

  RecordingTimeline get _timeline => timeline;

  /// 载入并开始播放；失败返回 false（调用方提示，不阻断阅读页）。
  Future<bool> start() async {
    if (_disposed) return false;
    try {
      await _audio.load(entry.path);
      await _audio.setSpeed(_speed);
      _positionSub = _audio.positionStream.listen((position) {
        _position = position;
        onPosition?.call(position);
        if (!_timeline.isEmpty) {
          final at = _timeline.positionAt(position.inMilliseconds);
          onAnchor?.call(at.line, at.char);
        }
      });
      _playingSub = _audio.playingStream.listen((playing) {
        _playing = playing;
        onPlayingChanged?.call(playing);
      });
      await _audio.play();
      _playing = true;
      return true;
    } catch (error) {
      onError?.call(error.toString());
      await _disposeAudio();
      return false;
    }
  }

  Future<void> toggle() async {
    if (_disposed) return;
    if (_playing) {
      await _audio.pause();
      _playing = false;
    } else {
      await _audio.play();
      _playing = true;
    }
  }

  Future<void> seek(Duration position) async {
    if (_disposed) return;
    final target = position < Duration.zero ? Duration.zero : position;
    await _audio.seek(target);
    _position = target;
    onPosition?.call(target);
    if (!_timeline.isEmpty) {
      final at = _timeline.positionAt(target.inMilliseconds);
      onAnchor?.call(at.line, at.char);
    }
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    _speed = speed;
    await _audio.setSpeed(speed);
  }

  double get progress {
    if (durationMs <= 0) return 0;
    final value = _position.inMilliseconds / durationMs;
    return value.clamp(0.0, 1.0);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playing = false;
    onPlayingChanged?.call(false);
    await _disposeAudio();
  }

  Future<void> _disposeAudio() async {
    await _positionSub?.cancel();
    await _playingSub?.cancel();
    _positionSub = null;
    _playingSub = null;
    await _audio.dispose();
  }

  /// 解析条目内时间轴；缺失或损坏时返回空轴（仍可播放音频）。
  static RecordingTimeline timelineOf(RecordingEntry entry) {
    final json = entry.timelineJson;
    if (json == null) {
      return RecordingTimeline(
        scriptId: entry.scriptId,
        durationMs: entry.durationMs,
        samples: const [],
      );
    }
    return RecordingTimeline.tryDecode(json) ??
        RecordingTimeline(
          scriptId: entry.scriptId,
          durationMs: entry.durationMs,
          samples: const [],
        );
  }
}
