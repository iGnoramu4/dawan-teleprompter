import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/lan_transfer.dart';

const _labels = LanTransferLabels(
  title: '局域网互传',
  hint: '同一 Wi-Fi',
  downloadAll: '下载全部',
  scriptList: '台本',
  noScripts: '暂无台本',
  importTitle: '导入',
  importButton: '选择',
  importDone: _importDone,
  importFailed: '失败',
);

String _importDone(int count) => '已导入 $count 篇台本';

void main() {
  late AppDatabase db;
  late ScriptRepository repo;
  late LanTransferServer server;
  late HttpClient client;

  setUp(() async {
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
    await repo.createScript(title: '互传稿', text: '第一段。\n\n第二段。');
    server = LanTransferServer(repo);
    client = HttpClient();
    await server.start(_labels);
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    await db.close();
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<int> getStatus(String path) async {
    final request = await client.getUrl(uri(path));
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<String> getBody(String path) async {
    final request = await client.getUrl(uri(path));
    final response = await request.close();
    return utf8.decode(await response.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    ));
  }

  test('带 token 的页面与下载可用，错误 token 返回 404', () async {
    expect(await getStatus('/t/${server.token}/'), 200);
    expect(await getBody('/t/${server.token}/'), contains('互传稿'));
    expect(await getStatus('/t/wrong/'), 404);

    final body = await getBody('/t/${server.token}/bundle.tps');
    expect(ScriptBundle.decode(body).scriptCount, 1);

    // 中文标题的单篇下载：Content-Disposition 必须是 ASCII。
    final id = (await repo.watchSummaries().first).single.id;
    final single = await getBody('/t/${server.token}/script/$id.tps');
    expect(ScriptBundle.decode(single).scriptCount, 1);
  });

  test('上传 .tps 可导入，坏文件返回 400', () async {
    final bundle = await repo.exportBundle();
    final request = await client.postUrl(uri('/t/${server.token}/import'));
    request.add(Uint8List.fromList(utf8.encode(bundle!.encode())));
    final response = await request.close();
    final text = utf8.decode(await response.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    ));
    expect(response.statusCode, 200);
    expect(text, contains('已导入 1'));

    final bad = await client.postUrl(uri('/t/${server.token}/import'));
    bad.add(Uint8List.fromList(utf8.encode('not a bundle')));
    final badResponse = await bad.close();
    await badResponse.drain<void>();
    expect(badResponse.statusCode, 400);
  });
}
