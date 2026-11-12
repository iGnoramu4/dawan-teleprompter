import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'remote_protocol.dart';

typedef RemoteStateProvider = RemoteState Function();
typedef RemoteCommandHandler = Future<void> Function(RemoteCommand command);

/// 局域网遥控服务端（计划 §10.5）：WebSocket + hello 鉴权 + 命令 ack + 状态下行。
///
/// 只监听 `InternetAddress.anyIPv4`，须由用户显式开启；关闭即停止监听。
/// 鉴权失败 3 次封禁来源地址 60 s。状态按行号下发，遥控端不做像素换算。
class RemoteServer {
  RemoteServer({
    required this.stateProvider,
    required this.onCommand,
    this.port = RemoteProtocol.defaultPort,
    this.stateInterval = const Duration(milliseconds: 200),
    this.authTimeout = RemoteProtocol.authTimeout,
    this.banDuration = RemoteProtocol.banDuration,
    this.maxAuthFailures = RemoteProtocol.maxAuthFailures,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RemoteStateProvider stateProvider;
  final RemoteCommandHandler onCommand;
  final int port;

  /// 状态下行节流间隔；仅在快照变化时发送。
  final Duration stateInterval;
  final Duration authTimeout;
  final Duration banDuration;
  final int maxAuthFailures;
  final DateTime Function() _clock;

  HttpServer? _server;
  Timer? _stateTimer;
  String _token = '';
  String? _lastState;
  final Map<String, DateTime> _bans = <String, DateTime>{};
  final Map<String, int> _failures = <String, int>{};
  final Set<_RemoteClient> _clients = <_RemoteClient>{};

  bool get isRunning => _server != null;

  /// 实际监听端口（`port` 传 0 时为系统分配端口）。
  int get boundPort => _server?.port ?? 0;

  String get token => _token;

  /// 启动服务并返回二维码配对信息。
  Future<RemotePairing> start() async {
    await stop();
    _token = RemoteProtocol.generateToken();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(
      (request) => unawaited(_handleRequest(request)),
      onError: (Object _) {},
    );
    _stateTimer = Timer.periodic(stateInterval, (_) => _broadcastState());
    return RemotePairing(
      host: await _localIpv4(),
      port: server.port,
      token: _token,
    );
  }

  Future<void> stop() async {
    _stateTimer?.cancel();
    _stateTimer = null;
    _lastState = null;
    final clients = _clients.toList();
    _clients.clear();
    for (final client in clients) {
      await client.close(1000, 'server stopped');
    }
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    _bans.clear();
    _failures.clear();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/ws') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final address = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      final bannedUntil = _bans[address];
      if (bannedUntil != null && bannedUntil.isAfter(_clock())) {
        await socket.close(4004, 'banned');
        return;
      }
      _attach(socket, address);
    } catch (_) {
      // 升级失败（对端断开/非 WebSocket 请求）时请求已结束，无需处理。
    }
  }

  void _attach(WebSocket socket, String address) {
    socket.pingInterval = RemoteProtocol.heartbeatInterval;
    final client = _RemoteClient(socket);
    var authed = false;
    final authTimer = Timer(authTimeout, () {
      if (!authed) {
        unawaited(client.close(4001, 'auth timeout'));
      }
    });
    socket.listen(
      (data) {
        if (!authed) {
          try {
            final message = RemoteProtocol.decodeInbound(data);
            if (message is! RemoteHello) {
              throw const RemoteProtocolException('首条消息必须是 hello');
            }
            if (message.token != _token) {
              _registerFailure(address);
              unawaited(client.close(4003, 'invalid token'));
              return;
            }
            authed = true;
            authTimer.cancel();
            _failures.remove(address);
            _clients.add(client);
            _sendState(client);
          } on RemoteProtocolException {
            unawaited(client.close(4002, 'bad message'));
          }
          return;
        }
        // 同一条连接上的命令串行处理，避免 seq 去重与执行顺序竞争。
        client.enqueue(() => _onMessage(client, data));
      },
      onDone: () {
        authTimer.cancel();
        _clients.remove(client);
      },
      onError: (Object _) {
        authTimer.cancel();
        _clients.remove(client);
      },
    );
  }

  Future<void> _onMessage(_RemoteClient client, Object? data) async {
    RemoteInbound message;
    try {
      message = RemoteProtocol.decodeInbound(data);
    } on RemoteProtocolException catch (error) {
      _sendError(client, error.message);
      return;
    }
    if (message is! RemoteCommandMessage) {
      _sendError(client, '已鉴权后只接受 cmd');
      return;
    }
    final command = message.command;
    if (command.seq <= client.lastSeq) {
      // 重复命令只回 ack，不重复执行（多遥控并发去重）。
      _ack(client, command.seq);
      return;
    }
    client.lastSeq = command.seq;
    try {
      await onCommand(command);
    } catch (error) {
      _sendError(client, '命令执行失败: $error');
      return;
    }
    _ack(client, command.seq);
  }

  void _broadcastState() {
    if (_clients.isEmpty) return;
    final encoded = jsonEncode(stateProvider().toJson());
    if (encoded == _lastState) return;
    _lastState = encoded;
    for (final client in _clients.toList()) {
      client.send(encoded);
    }
  }

  void _sendState(_RemoteClient client) {
    final encoded = jsonEncode(stateProvider().toJson());
    _lastState = encoded;
    client.send(encoded);
  }

  void _ack(_RemoteClient client, int seq) {
    client.send(jsonEncode(<String, Object?>{
      'v': RemoteProtocol.version,
      'type': RemoteProtocol.typeAck,
      'seq': seq,
    }));
  }

  void _sendError(_RemoteClient client, String message) {
    client.send(jsonEncode(<String, Object?>{
      'v': RemoteProtocol.version,
      'type': RemoteProtocol.typeError,
      'message': message,
    }));
  }

  void _registerFailure(String address) {
    final count = (_failures[address] ?? 0) + 1;
    if (count >= maxAuthFailures) {
      _failures.remove(address);
      _bans[address] = _clock().add(banDuration);
      return;
    }
    _failures[address] = count;
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

class _RemoteClient {
  _RemoteClient(this.socket);

  final WebSocket socket;
  int lastSeq = -1;
  Future<void> _queue = Future<void>.value();

  /// 串行排队：前一条命令处理完才处理下一条。
  void enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object _) {});
  }

  void send(String payload) {
    try {
      socket.add(payload);
    } catch (_) {
      // 对端已断开：由 onDone 清理。
    }
  }

  Future<void> close(int code, String reason) async {
    try {
      await socket.close(code, reason);
    } catch (_) {
      // 已关闭。
    }
  }
}
