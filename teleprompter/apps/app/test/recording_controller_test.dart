import 'dart:io';
import 'dart:typed_data';

import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/recording/recording_controller.dart';
import 'package:teleprompter/shared/recording/recording_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScriptRepository repo;
  late Directory dir;
  late RecordingStore store;

  setUp(() async {
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
    dir = Directory.systemTemp.createTempSync('tps-rec-ctl-');
    store = RecordingStore(root: Directory('${dir.path}/recordings'));
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('外部 PCM 流入 + 定时采样，停止后落库并生成 WAV/时间轴', () async {
    final script = await repo.createScript(title: '录制稿', text: '第一行。第二行。');
    var anchor = 0;
    final controller = RecordingController(
      repository: repo,
      store: store,
      scriptId: script.id,
      readAnchor: () => anchor,
      tickInterval: const Duration(milliseconds: 20),
    );

    await controller.start(useMic: false);
    expect(controller.isRecording, isTrue);

    controller.feed(Float32List.fromList([0.1, -0.2, 0.3]));
    anchor = 1;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    controller.feed(Float32List.fromList([0.4]));

    final entry = await controller.stop();
    expect(controller.isRecording, isFalse);
    expect(entry, isNotNull);

    final file = File(entry!.path);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(44 + 6));
    expect(entry.sizeBytes, file.lengthSync());
    expect(entry.durationMs, greaterThanOrEqualTo(100));
    expect(entry.timelineJson, isNotNull);

    final persisted = await repo.recordingsForScript(script.id);
    expect(persisted.single.id, entry.id);
    expect(controller.elapsedMs, 0);
  });

  test('取消录制删除半成品且不落库', () async {
    final script = await repo.createScript(title: '取消稿', text: '内容。');
    final controller = RecordingController(
      repository: repo,
      store: store,
      scriptId: script.id,
      readAnchor: () => 0,
    );

    await controller.start(useMic: false);
    final path = controller.audioPath;
    controller.feed(Float32List.fromList([0.5]));
    await controller.cancel();

    expect(controller.isRecording, isFalse);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isFalse);
    expect(await repo.recordingsForScript(script.id), isEmpty);
  });

  test('未开始录制时 stop/cancel/dispose 均安全', () async {
    final script = await repo.createScript(title: '空稿', text: '内容。');
    final controller = RecordingController(
      repository: repo,
      store: store,
      scriptId: script.id,
      readAnchor: () => 0,
    );

    expect(await controller.stop(), isNull);
    await controller.cancel();
    await controller.dispose();
    expect(controller.audioPath, isNull);
    expect(await repo.recordingsForScript(script.id), isEmpty);
  });

  test('超界浮点被裁剪，写入不中断录制', () async {
    final script = await repo.createScript(title: '错误稿', text: '内容。');
    final errors = <String>[];
    final controller = RecordingController(
      repository: repo,
      store: store,
      scriptId: script.id,
      readAnchor: () => 0,
      onError: errors.add,
    );

    await controller.start(useMic: false);
    controller.feed(
      Float32List.fromList([double.infinity, double.negativeInfinity]),
    );
    final entry = await controller.stop();
    expect(entry, isNotNull);
    expect(errors, isEmpty);
  });
}
