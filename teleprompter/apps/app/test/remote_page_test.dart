import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/remote/remote_client.dart';
import 'package:teleprompter/features/remote/remote_page.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
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

  Future<void> finish() async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

const _pairingText = 'tps://pair?host=127.0.0.1&port=7788&token=t1&v=1';

Widget _page({
  required RemoteClient Function(RemotePairing pairing) factory,
  RemoteScanLauncher? scanLauncher,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RemotePage(clientFactory: factory, scanLauncher: scanLauncher),
  );
}

Map<String, Object?> _stateJson({
  int anchor = 12,
  bool playing = true,
  bool locked = false,
  bool mirrored = false,
}) {
  return <String, Object?>{
    'v': 1,
    'type': 'state',
    'anchorLine': anchor,
    'layoutVersion': 3,
    'conf': 0.7,
    'speed': 1.2,
    'playing': playing,
    'scriptTitle': '测试稿',
    'progress': 0.4,
    'mirrored': mirrored,
    'locked': locked,
    'lineCount': 30,
    'anchorText': '当前行文本',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setUpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('非法配对串给出提示且不建立连接', (tester) async {
    await setUpView(tester);
    var connected = false;
    await tester.pumpWidget(
      _page(
        factory: (pairing) => RemoteClient(
          pairing: pairing,
          connector: (uri) async {
            connected = true;
            return _FakeTransport();
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'not-a-pairing');
    await tester.tap(find.text('连接'));
    await tester.pump();

    expect(find.text('配对串无效，请重新复制'), findsOneWidget);
    expect(connected, isFalse);
  });

  testWidgets('连接后显示状态并发送控制命令', (tester) async {
    await setUpView(tester);
    final transport = _FakeTransport();
    final client = RemoteClient(
      pairing: RemotePairing.tryParse(_pairingText)!,
      connector: (uri) async => transport,
    );
    await tester.pumpWidget(_page(factory: (pairing) => client));
    await tester.enterText(find.byType(TextField), _pairingText);
    await tester.tap(find.text('连接'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.isConnected, isTrue);
    expect(transport.sent.first['type'], RemoteProtocol.typeHello);

    transport.emit(jsonEncode(_stateJson()));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('测试稿'), findsOneWidget);
    expect(find.text('当前行文本'), findsOneWidget);
    expect(find.text('第 13 / 30 行'), findsOneWidget);
    expect(find.text('播放中'), findsOneWidget);

    await tester.tap(find.byTooltip('下一行'));
    await tester.pump();
    expect(
      transport.sent.last['action'],
      RemoteProtocol.actionNextLine,
    );

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();
    expect(transport.sent.last['action'], RemoteProtocol.actionPause);

    await tester.tap(find.byTooltip('降速'));
    await tester.pump();
    expect(transport.sent.last['delta'], -0.2);

    await tester.tap(find.byTooltip('镜像'));
    await tester.pump();
    expect(transport.sent.last['value'], isTrue);

    await tester.tap(find.byTooltip('锁定'));
    await tester.pump();
    transport.emit(jsonEncode(_stateJson(playing: false, locked: true)));
    await tester.pump(const Duration(milliseconds: 1));

    // 锁定后导航按钮禁用。
    final prevButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('上一行'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(prevButton.onPressed, isNull);
    expect(find.text('已暂停'), findsOneWidget);

    await tester.tap(find.text('断开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(client.state, RemoteConnectionState.idle);
    // 传输层的实际关闭由 remote_client_test 覆盖：广播流的 cancel 在
    // widget 测试的 fake async 下不会完成，这里只校验 UI 回到配对表单。
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('连接失败显示错误并可重新连接', (tester) async {
    await setUpView(tester);
    var attempts = 0;
    final client = RemoteClient(
      pairing: RemotePairing.tryParse(_pairingText)!,
      connector: (uri) async {
        attempts += 1;
        throw const _ConnectFailure();
      },
      maxRetries: 0,
      retryDelay: const Duration(milliseconds: 10),
    );
    await tester.pumpWidget(_page(factory: (pairing) => client));
    await tester.enterText(find.byType(TextField), _pairingText);
    await tester.tap(find.text('连接'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('连接失败'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('重新连接'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(attempts, 2);
  });

  testWidgets('扫码返回配对串后自动连接', (tester) async {
    await setUpView(tester);
    final transport = _FakeTransport();
    var launches = 0;
    final client = RemoteClient(
      pairing: RemotePairing.tryParse(_pairingText)!,
      connector: (uri) async => transport,
      maxRetries: 0,
    );
    await tester.pumpWidget(
      _page(
        factory: (pairing) => client,
        scanLauncher: (context) async {
          launches += 1;
          return RemotePairing.tryParse(_pairingText);
        },
      ),
    );

    expect(find.text('扫码配对'), findsOneWidget);
    await tester.tap(find.text('扫码配对'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(launches, 1);
    expect(find.text('已连接'), findsOneWidget);
    expect(transport.sent.first['type'], 'hello');
    expect(
      (find.byType(TextField).evaluate().isEmpty),
      isTrue,
      reason: '连接后离开配对表单',
    );
  });

  testWidgets('扫码取消则停留在配对表单', (tester) async {
    await setUpView(tester);
    await tester.pumpWidget(
      _page(
        factory: (pairing) => RemoteClient(pairing: pairing),
        scanLauncher: (context) async => null,
      ),
    );

    await tester.tap(find.text('扫码配对'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(TextField), findsOneWidget);
  });
}

class _ConnectFailure implements Exception {
  const _ConnectFailure();

  @override
  String toString() => '连接失败';
}
