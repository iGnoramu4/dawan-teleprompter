import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// 局域网互传页面的文案（由 UI 层按当前语言注入）。
class LanTransferLabels {
  const LanTransferLabels({
    required this.title,
    required this.hint,
    required this.downloadAll,
    required this.scriptList,
    required this.noScripts,
    required this.importTitle,
    required this.importButton,
    required this.importDone,
    required this.importFailed,
  });

  final String title;
  final String hint;
  final String downloadAll;
  final String scriptList;
  final String noScripts;
  final String importTitle;
  final String importButton;
  final String Function(int count) importDone;
  final String importFailed;
}

String _defaultImportDone(int count) => 'Imported $count';

/// 局域网互传：在本机开一个临时 HTTP 服务，供同一 Wi-Fi 下的浏览器下载/上传 `.tps`。
///
/// 所有路径都带随机 token，关闭服务即失效。只监听 IPv4，不对外开放公网。
class LanTransferServer {
  LanTransferServer(this._repository);

  final ScriptRepository _repository;

  HttpServer? _server;
  String _token = '';
  LanTransferLabels _labels = const LanTransferLabels(
    title: 'LAN Transfer',
    hint: '',
    downloadAll: 'Download all',
    scriptList: 'Scripts',
    noScripts: 'No scripts',
    importTitle: 'Import',
    importButton: 'Choose .tps',
    importDone: _defaultImportDone,
    importFailed: 'Import failed',
  );

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  String get token => _token;

  /// 启动服务并返回访问地址（含 token）。
  Future<String> start(LanTransferLabels labels) async {
    await stop();
    _labels = labels;
    _token = _generateToken();
    _server = await shelf_io.serve(_handle, InternetAddress.anyIPv4, 0);
    final ip = await _localIpv4();
    return 'http://$ip:${_server!.port}/t/$_token/';
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<Response> _handle(Request request) async {
    final segments = request.url.pathSegments;
    if (segments.length < 2 || segments[0] != 't' || segments[1] != _token) {
      return Response.notFound('not found');
    }
    // 末尾斜杠会产生空段，忽略它。
    final rest = segments.sublist(2).where((s) => s.isNotEmpty).toList();

    if (request.method == 'GET' && rest.isEmpty) {
      return Response.ok(
        await _buildPage(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
    if (request.method == 'GET' &&
        rest.length == 1 &&
        rest[0] == 'bundle.tps') {
      final bundle = await _repository.exportBundle();
      if (bundle == null) return Response.notFound(_labels.noScripts);
      return _fileResponse(bundle.encode(), 'teleprompter.tps');
    }
    if (request.method == 'GET' && rest.length == 2 && rest[0] == 'script') {
      final id = rest[1].endsWith('.tps')
          ? rest[1].substring(0, rest[1].length - 4)
          : rest[1];
      final document = await _repository.getDocument(id);
      if (document == null) return Response.notFound(_labels.noScripts);
      final preset = await _repository.loadPreset('script:$id');
      final bundle = ScriptBundle.fromDocuments(
        [document],
        presets: {id: preset},
      );
      return _fileResponse(
          bundle.encode(), '${_safeFileName(document.title)}.tps');
    }
    if (request.method == 'POST' && rest.length == 1 && rest[0] == 'import') {
      final body = await request.read().expand((chunk) => chunk).toList();
      if (body.length > 20 * 1024 * 1024) {
        return Response(413, body: _labels.importFailed);
      }
      try {
        final bundle = ScriptBundle.decode(utf8.decode(body));
        final imported = await _repository.importBundle(bundle);
        return Response.ok(_labels.importDone(imported));
      } catch (_) {
        return Response(400, body: _labels.importFailed);
      }
    }
    return Response.notFound('not found');
  }

  Response _fileResponse(String content, String fileName) {
    return Response.ok(
      content,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'content-disposition': 'attachment; filename="$fileName"',
      },
    );
  }

  Future<String> _buildPage() async {
    final token = _token;
    final active = await _repository.watchSummaries().first;
    final archived =
        await _repository.watchSummaries(view: ScriptView.archived).first;
    final scripts = [...active, ...archived];
    final items = scripts.isEmpty
        ? '<li>${_escape(_labels.noScripts)}</li>'
        : scripts
            .map(
              (item) => '<li><a href="/t/$token/script/${item.id}.tps">'
                  '${_escape(item.title)}</a></li>',
            )
            .join();
    return '''
<!doctype html>
<html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_escape(_labels.title)}</title>
<style>
body{font-family:system-ui,sans-serif;max-width:720px;margin:24px auto;padding:0 16px;line-height:1.6}
h1{font-size:22px}h2{font-size:17px;margin-top:24px}
a{color:#1565c0}li{margin:6px 0}
small{color:#666}
</style>
<h1>${_escape(_labels.title)}</h1>
<p><small>${_escape(_labels.hint)}</small></p>
<h2>${_escape(_labels.downloadAll)}</h2>
<p><a href="/t/$token/bundle.tps">teleprompter.tps</a></p>
<h2>${_escape(_labels.scriptList)}</h2>
<ul>$items</ul>
<h2>${_escape(_labels.importTitle)}</h2>
<p><input id="f" type="file" accept=".tps"></p>
<p><button onclick="upload()">${_escape(_labels.importButton)}</button></p>
<p id="r"></p>
<script>
async function upload(){
  const f = document.getElementById('f').files[0];
  if(!f) return;
  const r = await fetch('/t/$token/import', {method:'POST', body: await f.text()});
  document.getElementById('r').textContent = await r.text();
}
</script>
</html>
''';
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// HTTP 头只能放 ASCII，中文标题统一回退为 `script.tps`。
  String _safeFileName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    final safe = cleaned.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return safe.isEmpty ? 'script' : safe;
  }

  String _generateToken() {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _localIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '127.0.0.1';
  }
}
