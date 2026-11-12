import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/app_log.dart';

void main() {
  final log = AppLog.instance;

  test('未初始化时静默：enabled=false、读取为空', () async {
    expect(log.enabled, isFalse);
    expect(log.filePath, isNull);
    expect(log.directoryPath, '');
    expect(await log.readAll(), '');
    expect(log.recent, isEmpty);
  });

  test('初始化失败时不抛异常且保持不可用', () async {
    await log.init(Directory('/dev/null/app-log-test'));
    expect(log.enabled, isFalse);
    expect(await log.readAll(), '');
  });

  test('初始化后写入、刷新并读取当日日志', () async {
    final dir = Directory.systemTemp.createTempSync('tp_app_log_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await log.init(dir);
    // `IOSink` 有写缓冲，读文件前先 flush，避免并发跑测试时偶发读到空文件。
    await log.flush();
    expect(log.enabled, isTrue);
    expect(log.filePath, isNotNull);
    expect(log.directoryPath, log.filePath);
    expect(await log.readAll(), contains('log_started'));

    log.event('reader', 'start', {'anchor': 3, 'speed': 1.2});
    await log.flush();
    final content = await log.readAll();
    expect(content, contains('"event":"start"'));
    expect(content, contains('"anchor":3'));
    // 原始事件行同时进入内存环形缓冲。
    expect(log.recent.where((line) => line.contains('"event":"start"')),
        hasLength(1));
  });

  test('环形缓冲最多保留 200 条', () {
    for (var i = 0; i < 260; i++) {
      log.event('reader', 'tick', {'index': i});
    }
    expect(log.recent, hasLength(200));
    expect(log.recent.last, contains('"index":259'));
    expect(log.recent.first, contains('"index":60'));
  });

  test('日志文件被删除后读取返回空串', () async {
    final dir = Directory.systemTemp.createTempSync('tp_app_log_gone_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await log.init(dir);
    log.event('reader', 'before_delete');
    await log.flush();
    final path = log.filePath;
    expect(path, isNotNull);
    File(path!).deleteSync();
    expect(await log.readAll(), '');
  });

  test('刷新在不可用时也不抛异常', () async {
    await log.flush();
  });
}
