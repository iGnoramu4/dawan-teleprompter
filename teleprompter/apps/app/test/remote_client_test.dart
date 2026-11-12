import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/remote/remote_client.dart';
import 'package:teleprompter/shared/remote/remote_protocol.dart';

class _FakeTransport implements RemoteTransport {
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast();
  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  void send(String payload) {
    final json = RemoteProtocol.asJsonObject(payload);
    if (json != null) sent.add(json);
  }

  void emit(Object? payload) => _controller.add(payload);

  Future<void> finish() => _controller.close();

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

RemotePairing _pairing() => const RemotePairing(
      host: '127.0.0.1',
      port: 7788,
      token: 'token-1',
    );

void main() {
  test('连接后发送 hello，状态为 connected', () async {
    final transports = <_FakeTransport>[];
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async {
        expect(uri.scheme, 'ws');
        expect(uri.path, '/ws');
        final transport = _FakeTransport();
        transports.add(transport);
        return transport;
      },
    );
    await client.connect();
    expect(client.state, RemoteConnectionState.connected);
    expect(transports.single.sent.single['type'], RemoteProtocol.typeHello);
    expect(transports.single.sent.single['token'], 'token-1');
    expect(transports.single.sent.single['role'], 'remote');
    client.dispose();
  });

  test('状态、ack 与 error 下行更新客户端', () async {
    final transport = _FakeTransport();
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async => transport,
    );
    await client.connect();

    transport.emit(jsonEncode(<String, Object?>{
      'v': 1,
      'type': 'state',
      'anchorLine': 12,
      'layoutVersion': 3,
      'conf': 0.7,
      'speed': 1.2,
      'playing': true,
      'scriptTitle': '稿子',
      'progress': 0.4,
      'mirrored': true,
      'locked': false,
      'lineCount': 30,
      'anchorText': '当前行',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(client.remoteState?.anchorLine, 12);
    expect(client.remoteState?.lineCount, 30);
    expect(client.remoteState?.anchorText, '当前行');

    transport.emit(jsonEncode(<String, Object?>{
      'v': 1,
      'type': 'ack',
      'seq': 4,
    }));
    await Future<void>.delayed(Duration.zero);
    expect(client.lastAck, 4);

    transport.emit(jsonEncode(<String, Object?>{
      'v': 1,
      'type': 'error',
      'message': '未知动作',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(client.error, '未知动作');

    // 非法 JSON 与未知类型被忽略。
    transport.emit('not-json');
    transport.emit(jsonEncode(<String, Object?>{'v': 1, 'type': 'pong'}));
    await Future<void>.delayed(Duration.zero);
    expect(client.state, RemoteConnectionState.connected);
    client.dispose();
  });

  test('命令按 seq 递增，断开后不再发送', () async {
    final transport = _FakeTransport();
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async => transport,
    );
    await client.connect();

    expect(
      client.sendCommand(RemoteProtocol.actionNextLine),
      1,
    );
    expect(
      client.sendCommand(RemoteProtocol.actionSpeed, delta: 0.2),
      2,
    );
    final sent = transport.sent
        .where((item) => item['type'] == RemoteProtocol.typeCmd)
        .toList();
    expect(sent, hasLength(2));
    expect(sent.first['action'], RemoteProtocol.actionNextLine);
    expect(sent.last['delta'], 0.2);

    await client.disconnect();
    expect(client.state, RemoteConnectionState.idle);
    expect(client.sendCommand(RemoteProtocol.actionPlay), -1);
    expect(transport.closed, isTrue);
    client.dispose();
  });

  test('连接器抛错时进入 failed 并保留错误信息', () async {
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async => throw const SocketExceptionStub(),
    );
    await client.connect();
    expect(client.state, RemoteConnectionState.failed);
    expect(client.error, contains('connection refused'));
    client.dispose();
  });

  test('意外断开自动重连，达到上限后 failed', () async {
    final transports = <_FakeTransport>[];
    var attempts = 0;
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async {
        attempts += 1;
        final transport = _FakeTransport();
        transports.add(transport);
        return transport;
      },
      retryDelay: const Duration(milliseconds: 10),
      maxRetries: 1,
    );
    await client.connect();
    expect(attempts, 1);

    await transports.first.finish();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(client.retries, 1);
    expect(client.state, RemoteConnectionState.connected);
    expect(attempts, 2);

    // 第二次断开后达到重试上限。
    await transports.last.finish();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(client.state, RemoteConnectionState.failed);
    expect(client.error, contains('连接失败'));
    client.dispose();
  });

  test('dispose 关闭连接且不再重连', () async {
    final transport = _FakeTransport();
    final client = RemoteClient(
      pairing: _pairing(),
      connector: (uri) async => transport,
      retryDelay: const Duration(milliseconds: 10),
    );
    await client.connect();
    client.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(transport.closed, isTrue);
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'connection refused';
}
