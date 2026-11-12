import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/remote/remote_protocol.dart';
import 'package:teleprompter/shared/remote/remote_server.dart';

const _state0 = RemoteState(
  anchorLine: 0,
  layoutVersion: 1,
  confidence: 0.0,
  speed: 1.0,
  playing: false,
  scriptTitle: '测试稿',
  progress: 0.0,
  mirrored: false,
  locked: false,
);

Map<String, Object?> _hello(String token) => <String, Object?>{
      'v': 1,
      'type': 'hello',
      'role': 'remote',
      'token': token,
      'client': 'test',
    };

Map<String, Object?> _command(int seq, String action,
    {double? delta, bool? value, int? line}) {
  return <String, Object?>{
    'v': 1,
    'type': 'cmd',
    'seq': seq,
    'action': action,
    if (delta != null) 'delta': delta,
    if (value != null) 'value': value,
    if (line != null) 'line': line,
  };
}

/// 收集服务端下行帧，并捕获关闭码。
class _Inbox {
  _Inbox(WebSocket socket) {
    socket.listen(
      (Object? data) {
        final json = RemoteProtocol.asJsonObject(data);
        if (json != null) _add(json);
      },
      onDone: () {
        closeCode = socket.closeCode;
        closeReason = socket.closeReason;
        if (!_done.isCompleted) _done.complete();
      },
      onError: (Object _) {
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  final List<Map<String, Object?>> _messages = [];
  final List<Completer<void>> _waiters = [];
  final Completer<void> _done = Completer<void>();

  int? closeCode;
  String? closeReason;

  int get pending => _messages.length;

  Future<void> get done => _done.future.timeout(const Duration(seconds: 3));

  void _add(Map<String, Object?> message) {
    _messages.add(message);
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }

  Future<Map<String, Object?>> next() async {
    if (_messages.isEmpty) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future.timeout(const Duration(seconds: 3));
    }
    return _messages.removeAt(0);
  }

  Future<Map<String, Object?>> ofType(String type) async {
    for (var i = 0; i < 20; i++) {
      final message = await next();
      if (message['type'] == type) return message;
    }
    throw StateError('未收到类型为 $type 的消息');
  }
}

void main() {
  late RemoteServer server;
  late List<RemoteCommand> commands;
  late RemoteState state;
  late DateTime now;

  setUp(() async {
    commands = <RemoteCommand>[];
    state = _state0;
    now = DateTime(2026, 11, 6, 12);
    server = RemoteServer(
      stateProvider: () => state,
      onCommand: (command) async => commands.add(command),
      port: 0,
      stateInterval: const Duration(milliseconds: 50),
      clock: () => now,
    );
    await server.start();
  });

  tearDown(() async {
    await server.stop();
  });

  Future<(_Inbox, WebSocket)> connect([RemoteServer? target]) async {
    final host = target ?? server;
    // 由各用例负责关闭连接。
    // ignore: close_sinks
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${host.boundPort}/ws');
    return (_Inbox(socket), socket);
  }

  Future<void> authenticate(WebSocket socket) async {
    socket.add(jsonEncode(_hello(server.token)));
  }

  test('hello 鉴权通过后先收状态，命令回 ack', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);

    final state = await inbox.ofType('state');
    expect(state['anchorLine'], 0);
    expect(state['scriptTitle'], '测试稿');

    socket.add(jsonEncode(_command(1, RemoteProtocol.actionPlay)));
    final ack = await inbox.ofType('ack');
    expect(ack['seq'], 1);
    expect(commands.single.action, RemoteProtocol.actionPlay);

    await socket.close();
  });

  test('错误 token 关闭码 4003', () async {
    final (inbox, socket) = await connect();
    socket.add(jsonEncode(_hello('wrong-token')));
    await inbox.done;
    expect(inbox.closeCode, 4003);
  });

  test('连续 3 次错误 token 后封禁，过期后恢复', () async {
    for (var i = 0; i < RemoteProtocol.maxAuthFailures; i++) {
      final (inbox, socket) = await connect();
      socket.add(jsonEncode(_hello('wrong-token')));
      await inbox.done;
      expect(inbox.closeCode, 4003);
    }

    // 封禁期内即使 token 正确也拒连。
    final (bannedInbox, bannedSocket) = await connect();
    await authenticate(bannedSocket);
    await bannedInbox.done;
    expect(bannedInbox.closeCode, 4004);

    // 60 s 后解封。
    now = now.add(RemoteProtocol.banDuration + const Duration(seconds: 1));
    final (inbox, socket) = await connect();
    await authenticate(socket);
    expect((await inbox.ofType('state'))['type'], 'state');
    await socket.close();
  });

  test('重复 seq 只回 ack 不重复执行', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);
    await inbox.ofType('state');

    socket.add(jsonEncode(_command(5, RemoteProtocol.actionNextLine)));
    expect((await inbox.ofType('ack'))['seq'], 5);
    socket.add(jsonEncode(_command(5, RemoteProtocol.actionNextLine)));
    expect((await inbox.ofType('ack'))['seq'], 5);

    expect(commands, hasLength(1));
    await socket.close();
  });

  test('非法命令返回 error，连接保持可用', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);
    await inbox.ofType('state');

    socket.add(jsonEncode(<String, Object?>{
      'v': 1,
      'type': 'cmd',
      'seq': 1,
      'action': 'fly',
    }));
    final error = await inbox.ofType('error');
    expect(error['message'], contains('未知动作'));

    socket.add(jsonEncode(_command(2, RemoteProtocol.actionPause)));
    expect((await inbox.ofType('ack'))['seq'], 2);
    await socket.close();
  });

  test('已鉴权后再次 hello 返回 error', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);
    await inbox.ofType('state');

    socket.add(jsonEncode(_hello(server.token)));
    final error = await inbox.ofType('error');
    expect(error['message'], contains('只接受 cmd'));
    await socket.close();
  });

  test('状态变化按下行间隔推送', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);
    await inbox.ofType('state');

    // 同一状态不重复刷屏。
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(inbox.pending, 0);

    // 状态变化后才下发新帧。
    state = const RemoteState(
      anchorLine: 42,
      layoutVersion: 7,
      confidence: 0.82,
      speed: 1.4,
      playing: true,
      scriptTitle: '测试稿',
      progress: 0.31,
      mirrored: true,
      locked: false,
    );
    final changed = await inbox.ofType('state');
    expect(changed['anchorLine'], 42);
    expect(changed['layoutVersion'], 7);
    expect(changed['mirrored'], true);
    await socket.close();
  });

  test('stop 关闭客户端并停止监听', () async {
    final (inbox, socket) = await connect();
    await authenticate(socket);
    await inbox.ofType('state');

    await server.stop();
    await inbox.done;
    expect(inbox.closeCode, 1000);
    expect(server.isRunning, isFalse);

    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${server.boundPort}/ws'),
      throwsA(isA<SocketException>()),
    );
    await socket.close();
  });

  test('非 WebSocket 路径返回 404', () async {
    final client = HttpClient();
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/'));
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, 404);
    client.close(force: true);
  });

  test('hello 超时关闭码 4001', () async {
    final shortServer = RemoteServer(
      stateProvider: () => _state0,
      onCommand: (command) async {},
      port: 0,
      authTimeout: const Duration(milliseconds: 100),
      stateInterval: const Duration(milliseconds: 50),
    );
    await shortServer.start();
    addTearDown(shortServer.stop);

    final (inbox, socket) = await connect(shortServer);
    await inbox.done;
    expect(inbox.closeCode, 4001);
    await socket.close();
  });

  test('首条消息不是 hello 时关闭码 4002', () async {
    final (inbox, socket) = await connect();
    socket.add(jsonEncode(_command(1, RemoteProtocol.actionPlay)));
    await inbox.done;
    expect(inbox.closeCode, 4002);
  });
}
