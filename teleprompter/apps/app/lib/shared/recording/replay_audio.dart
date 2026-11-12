import 'package:just_audio/just_audio.dart';

/// 回放音频抽象：测试注入 fake，避免真实平台播放器。
abstract class ReplayAudio {
  Future<void> load(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Stream<Duration> get positionStream;

  Stream<bool> get playingStream;

  Future<void> dispose();
}

class JustAudioReplayAudio implements ReplayAudio {
  JustAudioReplayAudio({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> dispose() => _player.dispose();
}
