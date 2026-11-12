import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/recording/recording_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tps-export-');
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('导出 WAV + timeline.json + captions.srt', () async {
    final audio = File('${dir.path}/r.wav')..writeAsStringSync('fake-wave');
    final entry = RecordingEntry(
      id: 'r1',
      scriptId: 's1',
      path: audio.path,
      durationMs: 2000,
      createdAt: 1762345678000,
      sizeBytes: 9,
      timelineJson: '{"version":1,"scriptId":"s1","durationMs":2000,'
          '"samples":[{"t":0,"anchor":0},{"t":1000,"anchor":1}]}',
    );

    final saved = <String, Uint8List>{};
    final count = await exportRecording(
      entry: entry,
      lines: const ['第一行', '第二行'],
      saver: (name, bytes) async {
        saved[name] = bytes;
        return true;
      },
    );

    final base = recordingBaseName(entry);
    expect(base, matches(RegExp(r'^tps-\d{8}-\d{6}$')));
    expect(count, 3);
    expect(saved.keys.toList(), [
      '$base.wav',
      '$base.timeline.json',
      '$base.captions.srt',
    ]);
    expect(utf8.decode(saved.values.elementAt(0)), 'fake-wave');

    final timeline = jsonDecode(
      utf8.decode(saved['$base.timeline.json']!),
    ) as Map<String, Object?>;
    expect(timeline['version'], 1);
    expect(timeline['durationMs'], 2000);

    final srt = utf8.decode(saved['$base.captions.srt']!);
    expect(srt, contains('第一行'));
    expect(srt, contains('00:00:00,000 --> 00:00:01,000'));
    expect(srt, contains('00:00:01,000 --> 00:00:02,000'));
  });

  test('音频文件缺失时仍导出时间轴与字幕', () async {
    final entry = RecordingEntry(
      id: 'r2',
      scriptId: 's1',
      path: '${dir.path}/missing.wav',
      durationMs: 1000,
      createdAt: 1762345678000,
      sizeBytes: 0,
    );

    final names = <String>[];
    final count = await exportRecording(
      entry: entry,
      lines: const ['内容'],
      saver: (name, bytes) async {
        names.add(name);
        return true;
      },
    );

    expect(count, 2);
    final base = recordingBaseName(entry);
    expect(names, isNot(contains('$base.wav')));
    expect(names, contains('$base.timeline.json'));
    expect(names, contains('$base.captions.srt'));
  });

  test('用户取消保存时停止后续导出', () async {
    final audio = File('${dir.path}/r.wav')..writeAsStringSync('x');
    final entry = RecordingEntry(
      id: 'r4',
      scriptId: 's1',
      path: audio.path,
      durationMs: 100,
      createdAt: 1762345678000,
      sizeBytes: 1,
    );

    var calls = 0;
    final count = await exportRecording(
      entry: entry,
      lines: const ['内容'],
      saver: (name, bytes) async {
        calls += 1;
        return false;
      },
    );
    expect(calls, 1);
    expect(count, 0);
  });

  test('保存器异常向上抛出，调用方负责提示', () async {
    final entry = RecordingEntry(
      id: 'r3',
      scriptId: 's1',
      path: '${dir.path}/missing.wav',
      durationMs: 0,
      createdAt: 1762345678000,
      sizeBytes: 0,
    );

    await expectLater(
      exportRecording(
        entry: entry,
        lines: const [],
        saver: (name, bytes) async => throw StateError('denied'),
      ),
      throwsStateError,
    );
  });
}
