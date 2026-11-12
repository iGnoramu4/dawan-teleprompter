import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../shared/remote/remote_protocol.dart';

/// 遥控端传输层抽象：便于用 fake 覆盖 UI 与重连逻辑。
abstract interface class RemoteTransport {
  Stream<Object?> get stream;
  void send(String payload);
  Future<void> close([int? code, String? reason]);
}

/// 基于 `dart:io` WebSocket 的真实传输。
class WebSocketTransport implements RemoteTransport {
  WebSocketTransport(this._socket);

  final WebSocket _socket;

  @override
  Stream<Object?> get stream => _socket.map<Object?>((event) => event);

  @override
  void send(String payload) => _socket.add(payload);

  @override
  Future<void> close([int? code, String? reason]) =>
      _socket.close(code, reason);
}

typedef RemoteTransportConnector = Future<RemoteTransport> Function(Uri uri);

/// 默认连接器：5 s 建连超时，避免长期停在「正在连接」。
Future<RemoteTransport> connectWebSocket(Uri uri) async {
  // 连接由 [RemoteClient] 持有并在断开/释放时关闭。
  // ignore: close_sinks
  final socket = await WebSocket.connect(uri.toString())
      .timeout(const Duration(seconds: 5));
  return WebSocketTransport(socket);
}

enum RemoteConnectionState { idle, connecting, connected, disconnected, failed }

/// 遥控端会话：hello 鉴权、命令发送、状态接收与断线重连。
class RemoteClient extends ChangeNotifier {
  RemoteClient({
    required this.pairing,
    RemoteTransportConnector? connector,
    this.retryDelay = const Duration(seconds: 1),
    this.maxRetries = 3,
  }) : _connector = connector ?? connectWebSocket;

  final RemotePairing pairing;
  final RemoteTransportConnector _connector;
  final Duration retryDelay;
  final int maxRetries;

  RemoteConnectionState _state = RemoteConnectionState.idle;
  RemoteState? _remoteState;
  String? _error;
  int _seq = 0;
  int _lastAck = -1;
  int _retries = 0;
  bool _intentionalClose = false;
  bool _disposed = false;
  RemoteTransport? _transport;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;

  RemoteConnectionState get state => _state;
  RemoteState? get remoteState => _remoteState;
  String? get error => _error;
  int get lastAck => _lastAck;
  int get retries => _retries;
  bool get isConnected => _state == RemoteConnectionState.connected;

  /// 建立连接；[connect] 会重置重试计数。
  Future<void> connect() => _open(resetRetries: true);

  Future<void> _open({required bool resetRetries}) async {
    if (_disposed) return;
    _intentionalClose = false;
    if (resetRetries) _retries = 0;
    _retryTimer?.cancel();
    await _closeTransport();
    _setState(RemoteConnectionState.connecting);
    final uri = Uri(
      scheme: 'ws',
      host: pairing.host,
      port: pairing.port,
      path: '/ws',
    );
    try {
      final transport = await _connector(uri);
      if (_disposed) {
        await transport.close();
        return;
      }
      _transport = transport;
      _subscription = transport.stream.listen(
        _onPayload,
        onDone: _handleDisconnect,
        onError: (Object _) => _handleDisconnect(),
      );
      transport.send(
        jsonEncode(
          RemoteHello(token: pairing.token, client: 'teleprompter').toJson(),
        ),
      );
      _setState(RemoteConnectionState.connected);
    } catch (error) {
      _setState(RemoteConnectionState.failed, error: '$error');
    }
  }

  /// 发送一条命令；未连接时返回 `-1`。
  int sendCommand(
    String action, {
    double? delta,
    bool? value,
  }) {
    final transport = _transport;
    if (!isConnected || transport == null) return -1;
    _seq += 1;
    transport.send(
      jsonEncode(
        RemoteCommand(
          seq: _seq,
          action: action,
          delta: delta,
          value: value,
        ).toJson(),
      ),
    );
    return _seq;
  }

  /// 主动断开并停止重连。
  Future<void> disconnect() async {
    _intentionalClose = true;
    _retryTimer?.cancel();
    _retries = 0;
    _setState(RemoteConnectionState.idle);
    await _closeTransport();
  }

  void _onPayload(Object? payload) {
    final json = RemoteProtocol.asJsonObject(payload);
    if (json == null) return;
    switch (json['type']) {
      case RemoteProtocol.typeState:
        final state = RemoteState.tryParse(json);
        if (state != null) {
          _remoteState = state;
          _notify();
        }
      case RemoteProtocol.typeAck:
        final seq = json['seq'];
        if (seq is int) {
          _lastAck = seq;
          _notify();
        }
      case RemoteProtocol.typeError:
        final message = json['message'];
        _error = message is String ? message : '遥控端返回错误';
        _notify();
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _transport = null;
    if (_disposed || _intentionalClose) return;
    _setState(RemoteConnectionState.disconnected, error: '连接已断开');
    if (_retries >= maxRetries) {
      _setState(
        RemoteConnectionState.failed,
        error: '连接失败，请检查同一 Wi-Fi 后重试',
      );
      return;
    }
    _retries += 1;
    _retryTimer =
        Timer(retryDelay, () => unawaited(_open(resetRetries: false)));
  }

  Future<void> _closeTransport() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      try {
        await transport.close();
      } catch (_) {
        // 已关闭。
      }
    }
  }

  void _setState(RemoteConnectionState next, {String? error}) {
    if (_disposed) return;
    _state = next;
    _error = error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _intentionalClose = true;
    _retryTimer?.cancel();
    unawaited(_closeTransport());
    super.dispose();
  }
}
