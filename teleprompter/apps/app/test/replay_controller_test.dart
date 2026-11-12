import 'dart:async';

import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/recording/replay_audio.dart';
import 'package:teleprompter/shared/recording/replay_controller.dart';

class _FakeAudio implements ReplayAudio {
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final List<String> calls = <String>[];
  bool failLoad = false;
  bool disposed = false;
  Duration seeked = Duration.zero;
  double speed = 1;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  void emitPosition(Duration position) => _positions.add(position);

  @override
  Future<void> load(String path) async {
    calls.add('load:$path');
    if (failLoad) throw StateError('decode failed');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    seeked = position;
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _positions.close();
    await _playing.close();
  }
}

RecordingEntry _entry({String? timelineJson, int durationMs = 2000}) {
  return RecordingEntry(
    id: 'r1',
    scriptId: 's1',
    path: '/tmp/r1.wav',
    durationMs: durationMs,
    createdAt: 1,
    sizeBytes: 10,
    timelineJson: timelineJson,
  );
}

const _timelineJson = '{"version":1,"scriptId":"s1","durationMs":2000,'
    '"samples":[{"t":0,"anchor":0},{"t":1000,"anchor":10}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('播放位置按时间轴插值回调行号', () async {
    final audio = _FakeAudio();
    final positions = <Duration>[];
    final anchors = <int>[];
    final playing = <bool>[];
    final controller = ReplayController(
      entry: _entry(timelineJson: _timelineJson),
      timeline:
          ReplayController.timelineOf(_entry(timelineJson: _timelineJson)),
      audio: audio,
      onPosition: positions.add,
      onAnchor: (line, _) => anchors.add(line),
      onPlayingChanged: playing.add,
    );

    expect(await controller.start(), isTrue);
    expect(audio.calls, contains('play'));
    expect(controller.isPlaying, isTrue);

    audio.emitPosition(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);
    expect(positions.single.inMilliseconds, 500);
    expect(anchors.single, 5);
    expect(controller.progress, 0.25);

    await controller.seek(const Duration(milliseconds: 1500));
    expect(audio.seeked.inMilliseconds, 1500);
    expect(anchors.last, 10);

    await controller.setSpeed(2);
    expect(audio.speed, 2);
    expect(controller.speed, 2);

    await controller.toggle();
    expect(audio.calls.last, 'pause');
    await controller.toggle();
    expect(audio.calls.last, 'play');

    await controller.dispose();
    expect(controller.isPlaying, isFalse);
    expect(playing, isNotEmpty);
  });

  test('加载失败返回 false 并回调错误', () async {
    final audio = _FakeAudio()..failLoad = true;
    final errors = <String>[];
    final controller = ReplayController(
      entry: _entry(timelineJson: _timelineJson),
      timeline:
          ReplayController.timelineOf(_entry(timelineJson: _timelineJson)),
      audio: audio,
      onError: errors.add,
    );

    expect(await controller.start(), isFalse);
    expect(errors.single, contains('decode failed'));
    await controller.dispose();
  });

  test('时间轴缺失或损坏时回退为空轴，仍可播放', () async {
    final missing = ReplayController.timelineOf(_entry());
    expect(missing.isEmpty, isTrue);

    final broken = ReplayController.timelineOf(
      _entry(timelineJson: 'not-json'),
    );
    expect(broken.isEmpty, isTrue);

    final anchors = <int>[];
    final audio = _FakeAudio();
    final controller = ReplayController(
      entry: _entry(),
      timeline: missing,
      audio: audio,
      onAnchor: (line, _) => anchors.add(line),
    );
    expect(await controller.start(), isTrue);
    audio.emitPosition(const Duration(milliseconds: 100));
    await Future<void>.delayed(Duration.zero);
    expect(anchors, isEmpty);
    expect(controller.progress, closeTo(0.05, 1e-9));
    await controller.dispose();
  });

  test('seek 负数夹到 0', () async {
    final audio = _FakeAudio();
    final controller = ReplayController(
      entry: _entry(timelineJson: _timelineJson),
      timeline:
          ReplayController.timelineOf(_entry(timelineJson: _timelineJson)),
      audio: audio,
    );

    await controller.start();
    await controller.seek(const Duration(milliseconds: -50));
    expect(audio.seeked, Duration.zero);
    await controller.dispose();
  });

  test('进度条上限为 1', () async {
    final audio = _FakeAudio();
    final controller = ReplayController(
      entry: _entry(timelineJson: _timelineJson, durationMs: 1000),
      timeline:
          ReplayController.timelineOf(_entry(timelineJson: _timelineJson)),
      audio: audio,
    );
    await controller.start();
    audio.emitPosition(const Duration(milliseconds: 5000));
    await Future<void>.delayed(Duration.zero);
    expect(controller.progress, 1.0);
    await controller.dispose();
  });
}
