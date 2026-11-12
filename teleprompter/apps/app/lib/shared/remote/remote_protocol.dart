import 'dart:convert';
import 'dart:math';

/// 遥控协议常量与消息编解码（计划 §10.5）。
///
/// 传输为局域网 WebSocket + JSON 文本帧；状态使用「行号坐标系」，
/// 由渲染端统一分配行号（`anchorLine`/`layoutVersion`），遥控端不做像素换算。
abstract final class RemoteProtocol {
  /// 协议版本：v3 把锚点从"整行"下沉到"段内字符 + 视觉行"。
  ///
  /// v2 及更早的 `anchorLine` 指向按句切分的语义行；v3 的 `anchorLine`
  /// 指向段落，并新增 `anchorOffset`/`anchorRow`/`lineUnit` 明确语义。
  static const int version = 3;

  /// 仍接受 v1 遥控端上行消息（旧 App 不升级也能继续控制）。
  static const int minSupportedVersion = 1;

  static const int defaultPort = 7788;

  /// 协议层心跳间隔（WebSocket ping/pong）。
  static const Duration heartbeatInterval = Duration(seconds: 2);

  /// 连接后必须在此时长内完成 hello 鉴权。
  static const Duration authTimeout = Duration(seconds: 5);

  /// 连续鉴权失败次数达到该值后封禁来源地址。
  static const int maxAuthFailures = 3;
  static const Duration banDuration = Duration(seconds: 60);

  static const String typeHello = 'hello';
  static const String typeCmd = 'cmd';
  static const String typeState = 'state';
  static const String typeAck = 'ack';
  static const String typeError = 'error';

  static const String roleRemote = 'remote';
  static const String roleHost = 'host';

  static const String actionPlay = 'play';
  static const String actionPause = 'pause';
  static const String actionNextLine = 'next_line';
  static const String actionPrevLine = 'prev_line';
  static const String actionSpeed = 'speed';
  static const String actionScroll = 'scroll';
  static const String actionJump = 'jump';
  static const String actionMirror = 'mirror';
  static const String actionLock = 'lock';

  static const Set<String> actions = <String>{
    actionPlay,
    actionPause,
    actionNextLine,
    actionPrevLine,
    actionSpeed,
    actionScroll,
    actionJump,
    actionMirror,
    actionLock,
  };

  /// 128-bit 随机 token（32 位十六进制）。
  static String generateToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  /// 把收到的帧解析为 JSON 对象；不是合法对象时返回 `null`。
  static Map<String, Object?>? asJsonObject(Object? payload) {
    Object? decoded;
    if (payload is String) {
      try {
        decoded = jsonDecode(payload);
      } on FormatException {
        return null;
      }
    } else {
      decoded = payload;
    }
    if (decoded is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) return null;
      result[key] = entry.value;
    }
    return result;
  }

  /// 解析遥控端上行消息（hello / cmd）。不合法时抛 [RemoteProtocolException]。
  static RemoteInbound decodeInbound(Object? payload) {
    final json = asJsonObject(payload);
    if (json == null) {
      throw const RemoteProtocolException('不是 JSON 对象');
    }
    final remoteVersion = json['v'];
    if (remoteVersion is! int ||
        remoteVersion < minSupportedVersion ||
        remoteVersion > version) {
      throw const RemoteProtocolException('协议版本不匹配');
    }
    final type = json['type'];
    if (type is! String) {
      throw const RemoteProtocolException('缺少消息类型');
    }
    return switch (type) {
      typeHello => _decodeHello(json),
      typeCmd => RemoteCommandMessage(_decodeCommand(json)),
      _ => throw RemoteProtocolException('未知消息类型: $type'),
    };
  }

  static RemoteHello _decodeHello(Map<String, Object?> json) {
    if (json['role'] != roleRemote) {
      throw const RemoteProtocolException('role 必须为 remote');
    }
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const RemoteProtocolException('缺少配对 token');
    }
    final client = json['client'];
    return RemoteHello(
      token: token,
      client: client is String && client.isNotEmpty ? client : 'unknown',
    );
  }

  static RemoteCommand _decodeCommand(Map<String, Object?> json) {
    final seq = json['seq'];
    if (seq is! int || seq < 0) {
      throw const RemoteProtocolException('seq 必须为非负整数');
    }
    final action = json['action'];
    if (action is! String || !actions.contains(action)) {
      throw const RemoteProtocolException('未知动作');
    }
    final rawDelta = json['delta'];
    final delta = rawDelta is num ? rawDelta.toDouble() : null;
    final rawValue = json['value'];
    if (rawValue != null && rawValue is! bool) {
      throw const RemoteProtocolException('value 必须为布尔值');
    }
    final value = rawValue is bool ? rawValue : null;
    final rawLine = json['line'];
    if (rawLine != null && rawLine is! int) {
      throw const RemoteProtocolException('line 必须为整数');
    }
    final line = rawLine is int ? rawLine : null;
    switch (action) {
      case actionSpeed || actionScroll:
        if (delta == null) {
          throw const RemoteProtocolException('该动作需要 delta');
        }
      case actionJump:
        if (line == null) {
          throw const RemoteProtocolException('jump 需要 line');
        }
      case actionMirror || actionLock:
        if (value == null) {
          throw const RemoteProtocolException('该动作需要 value');
        }
    }
    return RemoteCommand(
      seq: seq,
      action: action,
      delta: delta,
      value: value,
      line: line,
    );
  }
}

/// 协议层错误（可安全地转为 `error` 消息返回给遥控端）。
class RemoteProtocolException implements Exception {
  const RemoteProtocolException(this.message);

  final String message;

  @override
  String toString() => 'RemoteProtocolException: $message';
}

/// 遥控端上行消息。
sealed class RemoteInbound {
  const RemoteInbound();
}

/// 首条鉴权消息。
final class RemoteHello extends RemoteInbound {
  const RemoteHello({required this.token, required this.client});

  final String token;
  final String client;

  Map<String, Object?> toJson() => <String, Object?>{
        'v': RemoteProtocol.version,
        'type': RemoteProtocol.typeHello,
        'role': RemoteProtocol.roleRemote,
        'token': token,
        'client': client,
      };
}

/// 包裹一条命令。
final class RemoteCommandMessage extends RemoteInbound {
  const RemoteCommandMessage(this.command);

  final RemoteCommand command;
}

/// 遥控端下发的命令。
class RemoteCommand {
  const RemoteCommand({
    required this.seq,
    required this.action,
    this.delta,
    this.value,
    this.line,
  });

  final int seq;
  final String action;
  final double? delta;
  final bool? value;

  /// 整篇连续文本的语义行号。
  final int? line;

  Map<String, Object?> toJson() => <String, Object?>{
        'v': RemoteProtocol.version,
        'type': RemoteProtocol.typeCmd,
        'seq': seq,
        'action': action,
        if (delta != null) 'delta': delta,
        if (value != null) 'value': value,
        if (line != null) 'line': line,
      };
}

/// 主控端下发的运行状态（行号坐标系）。
class RemoteState {
  const RemoteState({
    required this.anchorLine,
    required this.layoutVersion,
    required this.confidence,
    required this.speed,
    required this.playing,
    required this.scriptTitle,
    required this.progress,
    required this.mirrored,
    required this.locked,
    this.anchorOffset = 0,
    this.anchorRow = 0,
    this.rowProgress = 0,
    this.lineCount = 0,
    this.lineUnit = lineUnitSentence,
    this.anchorText = '',
    this.anchorRowText = '',
    this.rowHeight = 0,
    this.rowCount = 0,
    this.bandRatio = 0.5,
    this.typographyModel = 1,
  });

  /// 语义行单位常量：按句切行（v2 及更早）。
  static const String lineUnitSentence = 'sentence';

  /// 语义行单位常量：整篇连续文本的视觉行（v3 起）。
  static const String lineUnitParagraph = 'paragraph';

  final int anchorLine;

  /// 锚点在 `anchorLine` 内的字符偏移；v3 可选。
  final int anchorOffset;

  /// 锚点所在的视觉行号；v3 可选。
  final int anchorRow;

  /// 按视觉行计算的进度（0–1）；v3 可选。
  final double rowProgress;

  final int layoutVersion;
  final double confidence;
  final double speed;
  final bool playing;
  final String scriptTitle;

  /// 按语义行计算的进度（0–1），定义与 v2 相同。
  final double progress;
  final bool mirrored;
  final bool locked;

  /// 当前台本总行数（旧版本客户端可能为 0）。
  final int lineCount;

  /// `anchorLine` 的单位：`sentence`（v2 及更早）或 `paragraph`（v3）。
  final String lineUnit;

  /// 当前行文本（遥控端只读展示，截断到 [maxAnchorTextLength]）。
  final String anchorText;

  /// 当前视觉行文本；v3 可选，优先用于展示。
  final String anchorRowText;

  /// 视觉行高（逻辑像素）；v2 可选，旧遥控端可忽略。
  final double rowHeight;

  /// 视觉行总数；v2 可选。
  final int rowCount;

  /// 阅读带中心占屏高比例（0–1）；v2 可选。
  final double bandRatio;

  /// 排版模型：1 旧 / 2 紧凑；v2 可选。
  final int typographyModel;

  static const int maxAnchorTextLength = 60;

  Map<String, Object?> toJson() => <String, Object?>{
        'v': RemoteProtocol.version,
        'type': RemoteProtocol.typeState,
        'anchorLine': anchorLine,
        'anchorOffset': anchorOffset,
        'anchorRow': anchorRow,
        'rowProgress': rowProgress,
        'layoutVersion': layoutVersion,
        'conf': confidence,
        'speed': speed,
        'playing': playing,
        'scriptTitle': scriptTitle,
        'progress': progress,
        'mirrored': mirrored,
        'locked': locked,
        'lineCount': lineCount,
        'lineUnit': lineUnit,
        'anchorText': anchorText,
        'anchorRowText': anchorRowText,
        'rowHeight': rowHeight,
        'rowCount': rowCount,
        'bandRatio': bandRatio,
        'typographyModel': typographyModel,
      };

  /// 宽容解析：缺少可选字段时使用默认值，`anchorLine` 非法时返回 `null`。
  static RemoteState? tryParse(Map<String, Object?> json) {
    final anchorLine = json['anchorLine'];
    if (anchorLine is! int) return null;
    final layoutVersion = json['layoutVersion'];
    final lineCount = json['lineCount'];
    final anchorText = json['anchorText'];
    final scriptTitle = json['scriptTitle'];
    final rowCount = json['rowCount'];
    final typographyModel = json['typographyModel'];
    final anchorOffset = json['anchorOffset'];
    final anchorRow = json['anchorRow'];
    final anchorRowText = json['anchorRowText'];
    final lineUnit = json['lineUnit'];
    return RemoteState(
      anchorLine: anchorLine,
      anchorOffset: anchorOffset is int ? anchorOffset : 0,
      anchorRow: anchorRow is int ? anchorRow : 0,
      rowProgress: _asDouble(json['rowProgress']),
      layoutVersion: layoutVersion is int ? layoutVersion : 0,
      confidence: _asDouble(json['conf']),
      speed: _asDouble(json['speed'], fallback: 1.0),
      playing: json['playing'] == true,
      scriptTitle: scriptTitle is String ? scriptTitle : '',
      progress: _asDouble(json['progress']),
      mirrored: json['mirrored'] == true,
      locked: json['locked'] == true,
      lineCount: lineCount is int ? lineCount : 0,
      lineUnit:
          lineUnit == lineUnitParagraph ? lineUnitParagraph : lineUnitSentence,
      anchorText: anchorText is String ? anchorText : '',
      anchorRowText: anchorRowText is String ? anchorRowText : '',
      rowHeight: _asDouble(json['rowHeight']),
      rowCount: rowCount is int ? rowCount : 0,
      bandRatio: _asDouble(json['bandRatio'], fallback: 0.5),
      typographyModel: typographyModel is int ? typographyModel : 1,
    );
  }

  static double _asDouble(Object? value, {double fallback = 0.0}) {
    return value is num ? value.toDouble() : fallback;
  }
}

/// 二维码配对信息：`tps://pair?host=...&port=...&token=...&v=2`。
class RemotePairing {
  const RemotePairing({
    required this.host,
    required this.port,
    required this.token,
  });

  final String host;
  final int port;
  final String token;

  String toUriString() => Uri(
        scheme: 'tps',
        host: 'pair',
        queryParameters: <String, String>{
          'host': host,
          'port': '$port',
          'token': token,
          'v': '${RemoteProtocol.version}',
        },
      ).toString();

  /// 解析配对串；不是合法配对串时返回 `null`。
  static RemotePairing? tryParse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'tps' || uri.host != 'pair') return null;
    final host = uri.queryParameters['host'];
    final port = int.tryParse(uri.queryParameters['port'] ?? '');
    final token = uri.queryParameters['token'];
    if (host == null || host.isEmpty) return null;
    if (port == null || port < 1 || port > 65535) return null;
    if (token == null || token.isEmpty) return null;
    return RemotePairing(host: host, port: port, token: token);
  }
}
