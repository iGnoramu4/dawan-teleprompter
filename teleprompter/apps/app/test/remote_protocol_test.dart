import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/remote/remote_protocol.dart';

Map<String, Object?> _hello({String token = 'abc', String? client}) {
  return <String, Object?>{
    'v': 1,
    'type': 'hello',
    'role': 'remote',
    'token': token,
    if (client != null) 'client': client,
  };
}

Map<String, Object?> _cmd(Map<String, Object?> extra) {
  return <String, Object?>{'v': 1, 'type': 'cmd', 'seq': 1, ...extra};
}

void main() {
  group('配对串', () {
    test('生成与解析可往返', () {
      const pairing = RemotePairing(
        host: '192.168.1.5',
        port: 7788,
        token: '0123456789abcdef',
      );
      final text = pairing.toUriString();
      expect(text, startsWith('tps://pair?'));
      final parsed = RemotePairing.tryParse(text);
      expect(parsed, isNotNull);
      expect(parsed!.host, '192.168.1.5');
      expect(parsed.port, 7788);
      expect(parsed.token, '0123456789abcdef');
    });

    test('非法配对串返回 null', () {
      expect(RemotePairing.tryParse('not a uri'), isNull);
      expect(
          RemotePairing.tryParse('https://pair?host=a&port=1&token=t'), isNull);
      expect(
          RemotePairing.tryParse('tps://other?host=a&port=1&token=t'), isNull);
      expect(RemotePairing.tryParse('tps://pair?port=1&token=t'), isNull);
      expect(RemotePairing.tryParse('tps://pair?host=a&port=1'), isNull);
      expect(
          RemotePairing.tryParse('tps://pair?host=a&port=0&token=t'), isNull);
      expect(
        RemotePairing.tryParse('tps://pair?host=a&port=70000&token=t'),
        isNull,
      );
    });

    test('token 为 32 位十六进制且不重复', () {
      final first = RemoteProtocol.generateToken();
      final second = RemoteProtocol.generateToken();
      expect(first, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(first), isTrue);
      expect(first, isNot(second));
    });
  });

  group('上行消息解析', () {
    test('hello 合法并补全 client', () {
      final hello = RemoteProtocol.decodeInbound(_hello(client: 'android'));
      expect(hello, isA<RemoteHello>());
      expect((hello as RemoteHello).token, 'abc');
      expect(hello.client, 'android');

      final noClient =
          RemoteProtocol.decodeInbound(jsonEncode(_hello())) as RemoteHello;
      expect(noClient.client, 'unknown');
    });

    test('兼容 v1 遥控端，并接受 v2', () {
      final legacy = RemoteProtocol.decodeInbound(_hello(client: 'old'));
      expect((legacy as RemoteHello).client, 'old');
      final v2 = RemoteProtocol.decodeInbound(
        <String, Object?>{..._hello(), 'v': 2},
      );
      expect(v2, isA<RemoteHello>());
      final cmd = RemoteProtocol.decodeInbound(
        <String, Object?>{
          ..._cmd(<String, Object?>{'action': 'play'}),
          'v': 2
        },
      );
      expect(cmd, isA<RemoteCommandMessage>());
    });

    test('接受 v3（段落坐标）并兼容 v2 客户端', () {
      final v3 = RemoteProtocol.decodeInbound(
        <String, Object?>{..._hello(client: 'v3'), 'v': 3},
      );
      expect(v3, isA<RemoteHello>());
      final cmd = RemoteProtocol.decodeInbound(
        <String, Object?>{
          ..._cmd(<String, Object?>{'action': 'play'}),
          'v': 3,
        },
      );
      expect(cmd, isA<RemoteCommandMessage>());
    });

    test('hello 非法：版本/角色/token/非对象', () {
      expect(
        () => RemoteProtocol.decodeInbound('{'),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(<Object?>[]),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
            <String, Object?>{..._hello(), 'v': 4}),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
            <String, Object?>{..._hello(), 'role': 'host'}),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(_hello(token: '')),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(<String, Object?>{'v': 1}),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          <String, Object?>{'v': 1, 'type': 'unknown'},
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
    });

    test('cmd 合法：基础动作与可选字段', () {
      final play = RemoteProtocol.decodeInbound(
        _cmd(<String, Object?>{'action': 'play'}),
      );
      expect(play, isA<RemoteCommandMessage>());
      final command = (play as RemoteCommandMessage).command;
      expect(command.seq, 1);
      expect(command.action, RemoteProtocol.actionPlay);
      expect(command.delta, isNull);
      expect(command.value, isNull);

      final speed = RemoteProtocol.decodeInbound(
        _cmd(<String, Object?>{'action': 'speed', 'delta': 1}),
      ) as RemoteCommandMessage;
      expect(speed.command.delta, 1.0);

      final jump = RemoteProtocol.decodeInbound(
        _cmd(<String, Object?>{'action': 'jump', 'line': 3}),
      ) as RemoteCommandMessage;
      expect(jump.command.line, 3);

      final mirror = RemoteProtocol.decodeInbound(
        _cmd(<String, Object?>{'action': 'mirror', 'value': true}),
      ) as RemoteCommandMessage;
      expect(mirror.command.value, isTrue);
    });

    test('cmd 非法：缺字段、未知动作、类型错误', () {
      expect(
        () => RemoteProtocol.decodeInbound(
          <String, Object?>{'v': 1, 'type': 'cmd', 'action': 'play'},
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'seq': -1, 'action': 'play'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'fly'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'speed'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'jump'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'mirror'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'play', 'value': 'yes'}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
      expect(
        () => RemoteProtocol.decodeInbound(
          _cmd(<String, Object?>{'action': 'jump', 'line': 1.5}),
        ),
        throwsA(isA<RemoteProtocolException>()),
      );
    });
  });

  group('下行消息', () {
    test('RemoteState 按行号坐标系序列化', () {
      const state = RemoteState(
        anchorLine: 42,
        layoutVersion: 7,
        confidence: 0.82,
        speed: 1.0,
        playing: true,
        scriptTitle: '开场白',
        progress: 0.31,
        mirrored: false,
        locked: false,
      );
      final json = state.toJson();
      expect(json['type'], 'state');
      expect(json['anchorLine'], 42);
      expect(json['layoutVersion'], 7);
      expect(json['conf'], 0.82);
      expect(json['speed'], 1.0);
      expect(json['playing'], true);
      expect(json['scriptTitle'], '开场白');
      expect(json['progress'], 0.31);
      expect(json['lineCount'], 0);
      expect(json['anchorText'], '');
      expect(json['rowHeight'], 0.0);
      expect(json['rowCount'], 0);
      expect(json['bandRatio'], 0.5);
      expect(json['typographyModel'], 1);
    });

    test('v2 可选字段序列化并向下兼容', () {
      const state = RemoteState(
        anchorLine: 3,
        layoutVersion: 9,
        confidence: 0.6,
        speed: 1.2,
        playing: false,
        scriptTitle: '稿子',
        progress: 0.2,
        mirrored: true,
        locked: false,
        rowHeight: 62.5,
        rowCount: 88,
        bandRatio: 0.34,
        typographyModel: 2,
      );
      final json = state.toJson();
      expect(json['v'], RemoteProtocol.version);
      expect(json['rowHeight'], 62.5);
      expect(json['rowCount'], 88);
      expect(json['bandRatio'], 0.34);
      expect(json['typographyModel'], 2);
      final restored = RemoteState.tryParse(json);
      expect(restored?.rowHeight, 62.5);
      expect(restored?.rowCount, 88);
      expect(restored?.bandRatio, 0.34);
      expect(restored?.typographyModel, 2);
    });

    test('v3 段落坐标字段序列化与回退', () {
      const state = RemoteState(
        anchorLine: 2,
        anchorOffset: 7,
        anchorRow: 5,
        rowProgress: 0.4,
        layoutVersion: 11,
        confidence: 0.7,
        speed: 1.2,
        playing: true,
        scriptTitle: '稿子',
        progress: 0.2,
        mirrored: false,
        locked: false,
        lineCount: 6,
        lineUnit: RemoteState.lineUnitParagraph,
        anchorText: '整段文字',
        anchorRowText: '视觉行',
        rowCount: 14,
      );
      final json = state.toJson();
      expect(json['anchorOffset'], 7);
      expect(json['anchorRow'], 5);
      expect(json['rowProgress'], 0.4);
      expect(json['lineUnit'], 'paragraph');
      expect(json['anchorRowText'], '视觉行');
      expect(json['v'], 3);

      final restored = RemoteState.tryParse(json);
      expect(restored?.anchorOffset, 7);
      expect(restored?.anchorRow, 5);
      expect(restored?.rowProgress, 0.4);
      expect(restored?.lineUnit, 'paragraph');
      expect(restored?.anchorRowText, '视觉行');

      // v2 状态缺少新字段时回退到整行语义，不改变旧字段含义。
      final legacy = RemoteState.tryParse(<String, Object?>{
        'anchorLine': 4,
        'layoutVersion': 3,
        'conf': 0.5,
        'speed': 1.0,
        'playing': false,
        'scriptTitle': '旧稿',
        'progress': 0.1,
        'mirrored': false,
        'locked': false,
      });
      expect(legacy?.anchorOffset, 0);
      expect(legacy?.anchorRow, 0);
      expect(legacy?.rowProgress, 0.0);
      expect(legacy?.lineUnit, RemoteState.lineUnitSentence);
      expect(legacy?.anchorRowText, '');
      expect(legacy?.anchorLine, 4);
    });

    test('RemoteState.tryParse 宽容解析与非法回退', () {
      final parsed = RemoteState.tryParse(<String, Object?>{
        'anchorLine': 5,
        'layoutVersion': 2,
        'conf': 0.5,
        'speed': 1.2,
        'playing': true,
        'scriptTitle': '稿子',
        'progress': 0.3,
        'mirrored': true,
        'locked': false,
        'lineCount': 20,
        'anchorText': '当前行',
      });
      expect(parsed?.anchorLine, 5);
      expect(parsed?.lineCount, 20);
      expect(parsed?.anchorText, '当前行');
      expect(parsed?.mirrored, isTrue);
      expect(parsed?.rowHeight, 0.0);
      expect(parsed?.rowCount, 0);
      expect(parsed?.bandRatio, 0.5);
      expect(parsed?.typographyModel, 1);

      // 可选字段缺失时使用默认值。
      final partial = RemoteState.tryParse(<String, Object?>{'anchorLine': 1});
      expect(partial?.speed, 1.0);
      expect(partial?.lineCount, 0);
      expect(partial?.scriptTitle, '');
      expect(partial?.anchorText, '');

      // anchorLine 非法时返回 null。
      expect(RemoteState.tryParse(<String, Object?>{}), isNull);
      expect(
          RemoteState.tryParse(<String, Object?>{'anchorLine': 'x'}), isNull);
    });

    test('RemoteCommand 只输出已提供的可选字段', () {
      const minimal = RemoteCommand(seq: 2, action: 'play');
      expect(minimal.toJson().containsKey('delta'), isFalse);
      expect(minimal.toJson().containsKey('value'), isFalse);
      expect(minimal.toJson().containsKey('line'), isFalse);

      const full = RemoteCommand(
        seq: 3,
        action: 'jump',
        delta: 0.5,
        value: true,
        line: 7,
      );
      expect(full.toJson()['delta'], 0.5);
      expect(full.toJson()['value'], true);
      expect(full.toJson()['line'], 7);
    });
  });
}
