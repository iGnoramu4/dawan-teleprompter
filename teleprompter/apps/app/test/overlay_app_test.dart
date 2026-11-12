import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overlay_bridge/overlay_bridge.dart';
import 'package:teleprompter/features/reader/overlay/overlay_app.dart';
import 'package:teleprompter/features/reader/overlay/overlay_channel.dart';

const _bridgeChannel =
    BasicMessageChannel<dynamic>(overlayBridgeChannel, JSONMessageCodec());
const _overlayChannel = MethodChannel('x-slayer/overlay');

/// 模拟原生 → 浮窗引擎的消息投递。
Future<void> _deliver(WidgetTester tester, Object? payload) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    overlayBridgeChannel,
    const JSONMessageCodec().encodeMessage(payload),
    (_) {},
  );
  await tester.pump();
}

Map<String, Object?> _initMessage({
  List<String> lines = const ['第一行', '第二行', '第三行'],
  int anchor = 0,
  int lineCount = 3,
  double fontSize = 24,
  double opacity = 0.92,
  String theme = 'stageDark',
}) {
  return {
    'type': OverlayChannel.typeInit,
    'title': '悬浮稿',
    'lines': lines,
    'anchor': anchor,
    'lineCount': lineCount,
    'fontSize': fontSize,
    'opacity': opacity,
    'theme': theme,
    'started': false,
    'playing': false,
    'locked': false,
    'voiceOn': false,
    'micStatus': null,
  };
}

Map<String, Object?> _stateMessage({
  bool started = true,
  bool playing = true,
  bool locked = false,
  bool voiceOn = false,
  String? micStatus,
}) {
  return {
    'type': OverlayChannel.typeState,
    'started': started,
    'playing': playing,
    'locked': locked,
    'voiceOn': voiceOn,
    'micStatus': micStatus,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_overlayChannel, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_overlayChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(_bridgeChannel, null);
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('未收到 init 时显示等待态并重试 ready', (tester) async {
    final sent = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      _bridgeChannel,
      (message) async {
        sent.add(message);
        return null;
      },
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.text('Waiting for the reading page…'), findsNothing);

    // init 未到：按 500 ms 间隔重试 ready，最多 10 次后停止。
    expect(sent, hasLength(1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, hasLength(2));
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // 第 10 次计时只判断并取消，不再发 ready。
    expect(sent.whereType<Map<Object?, Object?>>().length, 10);
    final before = sent.length;
    await tester.pump(const Duration(seconds: 2));
    expect(sent, hasLength(before));

    await unmount(tester);
  });

  testWidgets('收到 init 后渲染标题、行文本与字号，并停止重试', (tester) async {
    final sent = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      _bridgeChannel,
      (message) async {
        sent.add(message);
        return null;
      },
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    final before = sent.length;

    await _deliver(tester, _initMessage(fontSize: 28));
    expect(find.text('悬浮稿'), findsOneWidget);
    expect(find.text('第一行'), findsOneWidget);
    expect(find.text('第三行'), findsOneWidget);
    final lineText = tester.widget<Text>(find.text('第一行'));
    expect(lineText.style?.fontSize, 28);

    // 已有内容后不再重试 ready。
    await tester.pump(const Duration(seconds: 3));
    expect(sent, hasLength(before));

    await unmount(tester);
  });

  testWidgets('init 的 lines 非法时按空稿处理', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, {
      ..._initMessage(),
      'lines': 'not-a-list',
    });
    expect(find.text('第一行'), findsNothing);
    await unmount(tester);
  });

  testWidgets('anchor 消息切换可见行窗口', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(
      tester,
      _initMessage(
        lines: const ['零', '一', '二', '三', '四', '五'],
      ),
    );
    expect(find.text('零'), findsOneWidget);
    expect(find.text('五'), findsNothing);

    await _deliver(tester, {
      'type': OverlayChannel.typeAnchor,
      'anchor': 4,
    });
    // 3 行窗口、锚点 4 → 显示 3/4/5。
    expect(find.text('五'), findsOneWidget);
    expect(find.text('零'), findsNothing);

    // 重复锚点不触发重建。
    await _deliver(tester, {
      'type': OverlayChannel.typeAnchor,
      'anchor': 4,
    });
    await unmount(tester);
  });

  testWidgets('state 消息驱动麦克风角标的全部状态', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());

    await _deliver(tester, _stateMessage(voiceOn: true, micStatus: 'loading'));
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

    await _deliver(tester, _stateMessage(voiceOn: true, micStatus: 'paused'));
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

    await _deliver(
        tester, _stateMessage(voiceOn: true, micStatus: 'listening'));
    expect(find.byIcon(Icons.mic), findsWidgets);

    await _deliver(tester, _stateMessage(voiceOn: true, micStatus: 'silent'));
    expect(find.byIcon(Icons.mic_off), findsOneWidget);

    await _deliver(
      tester,
      _stateMessage(voiceOn: true, micStatus: 'lowConfidence'),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    await _deliver(
      tester,
      _stateMessage(voiceOn: true, micStatus: 'background'),
    );
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

    // 未知状态回退到加载中。
    await _deliver(tester, _stateMessage(voiceOn: true, micStatus: 'unknown'));
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

    // 关闭语音后角标消失。
    await _deliver(tester, _stateMessage());
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await unmount(tester);
  });

  testWidgets('控制按钮把动作发回主引擎', (tester) async {
    final sent = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      _bridgeChannel,
      (message) async {
        sent.add(message);
        return null;
      },
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());
    sent.clear();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(
      sent
          .whereType<Map<Object?, Object?>>()
          .where((item) => item.containsKey('action'))
          .map((item) => item['action'])
          .toList(),
      [
        OverlayChannel.actionPrevLine,
        OverlayChannel.actionNextLine,
        OverlayChannel.actionTogglePause,
        OverlayChannel.actionToggleMic,
        OverlayChannel.actionToggleLock,
      ],
    );
    expect(
      sent.whereType<Map<Object?, Object?>>().where(
            (item) => item['type'] == OverlayChannel.typeClose,
          ),
      hasLength(1),
    );

    await unmount(tester);
  });

  testWidgets('开始且播放中显示暂停图标', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());
    await _deliver(tester, _stateMessage());
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await _deliver(tester, _stateMessage(playing: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('锁定后控制栏替换为解锁条且可点击解锁', (tester) async {
    final sent = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      _bridgeChannel,
      (message) async {
        sent.add(message);
        return null;
      },
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());
    sent.clear();

    await _deliver(tester, _stateMessage(locked: true));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    expect(find.byIcon(Icons.lock), findsWidgets);

    await tester.tap(find.byType(InkWell).last);
    await tester.pump();
    expect(
      sent
          .whereType<Map<Object?, Object?>>()
          .map((item) => item['action'])
          .toList(),
      [OverlayChannel.actionToggleLock],
    );

    await unmount(tester);
  });

  testWidgets('旧「全稿」配置迁移为 5 行窗口，不再渲染全稿', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(
      tester,
      _initMessage(
        lines: const ['一', '二', '三', '四', '五', '六'],
        lineCount: 0,
      ),
    );
    expect(find.byType(ListView), findsNothing);
    expect(find.text('五'), findsOneWidget);
    expect(find.text('六'), findsNothing);
    await unmount(tester);
  });

  testWidgets('style 消息立即重排窗口', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _overlayChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());

    await _deliver(tester, {
      'type': OverlayChannel.typeStyle,
      'widthDp': 500,
      'opacity': 0.5,
      'lineCount': 5,
      'fontSize': 30,
    });
    await tester.pump();

    final resize = calls.where((call) => call.method == 'resizeOverlay');
    expect(resize, hasLength(1));
    final args = resize.single.arguments as Map<Object?, Object?>;
    expect(args['width'], 500);
    expect(args['height'], 420);
    expect(args['enableDrag'], true);
    final lineText = tester.widget<Text>(find.text('第一行'));
    expect(lineText.style?.fontSize, 30);

    // 非数字字段回退为归一化默认值，不应崩溃。
    await _deliver(tester, {
      'type': OverlayChannel.typeStyle,
      'widthDp': 100,
      'opacity': 2.0,
      'lineCount': 7,
    });
    await tester.pump();
    final normalized = calls.last.arguments as Map<Object?, Object?>;
    expect(normalized['width'], 200);
    expect(normalized['height'], 420);

    await unmount(tester);
  });

  testWidgets('重排失败时静默降级', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _overlayChannel,
      (call) async => throw PlatformException(code: 'unavailable'),
    );

    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage());
    await _deliver(tester, {
      'type': OverlayChannel.typeStyle,
      'widthDp': 500,
      'lineCount': 5,
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('非法消息被忽略', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, 'not-a-map');
    await _deliver(tester, {'no': 'type'});
    expect(find.text('第一行'), findsNothing);
    await unmount(tester);
  });

  testWidgets('白色舞台主题也可渲染', (tester) async {
    await tester.pumpWidget(const ReaderOverlayApp());
    await tester.pump();
    await _deliver(tester, _initMessage(theme: 'stageWhite'));
    expect(find.text('悬浮稿'), findsOneWidget);
    await unmount(tester);
  });
}
