import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overlay_bridge/overlay_bridge.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:teleprompter/data/providers.dart';
import 'package:teleprompter/features/reader/overlay/overlay_channel.dart';
import 'package:teleprompter/features/reader/overlay/overlay_window_service.dart';
import 'package:teleprompter/features/reader/reader_page.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/reader_settings/reader_bar_settings.dart';
import 'package:teleprompter/shared/reader_settings/reader_defaults_store.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';
import 'package:teleprompter/shared/remote/remote_protocol.dart';

const _pluginChannel = MethodChannel('x-slayer/overlay_channel');
const _overlayChannel = MethodChannel('x-slayer/overlay');
const _platformChannel = MethodChannel('com.tp.prompter.teleprompter/platform');
const _bridgeChannel =
    BasicMessageChannel<dynamic>(overlayBridgeChannel, JSONMessageCodec());
const _recordChannel = MethodChannel('com.llfbandit.record/messages');
const _displayChannel = MethodChannel('tps/display');

ScriptDocument _sectionDoc(
    {String id = 's2', List<ScriptMarker> markers = const []}) {
  final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
  return ScriptDocument(
    id: id,
    title: '分段台本',
    rawText: '第一段内容简短\n\n第二段内容简短\n\n第三段内容简短',
    sections: const [
      ScriptSection(id: 'sec1', scriptId: 's2', ord: 0, text: '第一段内容简短'),
      ScriptSection(id: 'sec2', scriptId: 's2', ord: 1, text: '第二段内容简短'),
      ScriptSection(id: 'sec3', scriptId: 's2', ord: 2, text: '第三段内容简短'),
    ],
    markers: markers,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _reader(
  AppDatabase db,
  ScriptDocument document, {
  int initialAnchor = 0,
}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReaderPage(document: document, initialAnchor: initialAnchor),
    ),
  );
}

Future<void> _deliver(WidgetTester tester, Object? payload) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    overlayBridgeChannel,
    const JSONMessageCodec().encodeMessage(payload),
    (_) {},
  );
  await tester.pump();
}

/// 阅读页的 Ticker 会持续请求帧，pumpAndSettle 永远无法收敛，改用固定步进。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 读取控制栏「当前行 / 总行数」里的总行数。
int _totalLines(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((data) => RegExp(r'^\d+ / \d+$').hasMatch(data));
  expect(texts, isNotEmpty);
  return int.parse(texts.first.split('/').last.trim());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScriptRepository repo;
  late TestDefaultBinaryMessenger messenger;
  late List<MethodCall> pluginCalls;
  late List<dynamic> sent;
  late List<MethodCall> displayCalls;
  late List<Object?> displayList;

  bool permissionGranted = true;
  bool requestGranted = true;

  setUp(() async {
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
    // 功能栏默认只留跟随控制；交互测试需要所有按钮可点。
    await repo.setSetting(
      readerBarActionsKey,
      ReaderBarAction.values.map((action) => action.name).join(','),
    );
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    pluginCalls = <MethodCall>[];
    sent = <dynamic>[];
    displayCalls = <MethodCall>[];
    displayList = <Object?>[];
    permissionGranted = true;
    requestGranted = true;

    messenger.setMockMethodCallHandler(_pluginChannel, (call) async {
      pluginCalls.add(call);
      switch (call.method) {
        case 'checkPermission':
          return permissionGranted;
        case 'requestPermission':
          return requestGranted;
        case 'isOverlayActive':
          return false;
        case 'getOverlayPosition':
          return {'x': 12.0, 'y': 300.0};
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(_overlayChannel, (call) async => null);
    messenger.setMockMethodCallHandler(_platformChannel, (call) async {
      if (call.method == 'notificationStatus') return true;
      if (call.method == 'requestNotification') return true;
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(_bridgeChannel,
        (message) async {
      sent.add(message);
      return null;
    });
    // record 插件的录音器构造即发通道消息；桩掉通道并让权限检查失败，
    // 从而在测试环境稳定走到“麦克风启动失败”分支。
    messenger.setMockMethodCallHandler(_recordChannel, (call) async {
      if (call.method == 'hasPermission') return false;
      return null;
    });
    messenger.setMockMethodCallHandler(_displayChannel, (call) async {
      displayCalls.add(call);
      if (call.method == 'listDisplays') return displayList;
      return null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pluginChannel, null);
    messenger.setMockMethodCallHandler(_overlayChannel, null);
    messenger.setMockMethodCallHandler(_platformChannel, null);
    messenger.setMockMethodCallHandler(_recordChannel, null);
    messenger.setMockMethodCallHandler(_displayChannel, null);
    messenger.setMockDecodedMessageHandler<dynamic>(_bridgeChannel, null);
    await db.close();
  });

  Future<void> setUpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> mountReader(
    WidgetTester tester,
    ScriptDocument document, {
    int initialAnchor = 0,
  }) async {
    addTearDown(() async {
      // 先卸载页面，让 dispose 里的锚点/最近浏览写入在数据库关闭前完成。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
    await tester
        .pumpWidget(_reader(db, document, initialAnchor: initialAnchor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('悬浮窗权限流程', () {
    testWidgets('权限弹窗取消后不请求、不显示浮窗', (tester) async {
      permissionGranted = false;
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.picture_in_picture_alt_outlined));
      await _settle(tester);
      expect(find.text('需要悬浮窗权限'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await _settle(tester);

      expect(
        pluginCalls.any((call) => call.method == 'requestPermission'),
        isFalse,
      );
      expect(
          find.byIcon(Icons.picture_in_picture_alt_outlined), findsOneWidget);
      expect(find.textContaining('未获得悬浮窗权限'), findsNothing);
    });

    testWidgets('授权被拒绝时提示并保留应用内提词', (tester) async {
      permissionGranted = false;
      requestGranted = false;
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.picture_in_picture_alt_outlined));
      await _settle(tester);
      await tester.tap(find.text('去授权'));
      await _settle(tester);

      expect(find.text('未获得悬浮窗权限，已保留应用内提词'), findsOneWidget);
      expect(
          find.byIcon(Icons.picture_in_picture_alt_outlined), findsOneWidget);
      expect(
        pluginCalls.where((call) => call.method == 'showOverlay'),
        isEmpty,
      );
    });

    testWidgets('授权通过后显示浮窗、发送初始化并可关闭', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());
      sent.clear();

      await tester.tap(find.byIcon(Icons.picture_in_picture_alt_outlined));
      await _settle(tester);

      final show =
          pluginCalls.singleWhere((call) => call.method == 'showOverlay');
      final args = show.arguments as Map<Object?, Object?>;
      expect(args['width'], 1080);
      expect(args['height'], 900);
      expect(args['overlayTitle'], '提词悬浮窗');

      final init = sent.whereType<Map<Object?, Object?>>().singleWhere(
            (message) => message['type'] == OverlayChannel.typeInit,
          );
      expect(init['title'], '分段台本');
      expect(init['lines'], ['第一段内容简短', '第二段内容简短', '第三段内容简短']);
      expect(init['anchor'], 0);
      expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);

      // 未开始滚动时不重复发送锚点。
      sent.clear();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        sent
            .whereType<Map<Object?, Object?>>()
            .where((m) => m['type'] == OverlayChannel.typeAnchor),
        isEmpty,
      );

      // 关闭浮窗时保存位置。
      await tester.tap(find.byIcon(Icons.picture_in_picture_alt));
      await _settle(tester);
      expect(
        pluginCalls.any((call) => call.method == 'closeOverlay'),
        isTrue,
      );
      expect(
          find.byIcon(Icons.picture_in_picture_alt_outlined), findsOneWidget);
      final saved = await repo.loadPreset(overlaySettingsKey);
      expect(saved?['x'], 12.0);
      expect(saved?['y'], 300.0);
    });
  });

  group('悬浮窗消息', () {
    testWidgets('ready/position/control/close 消息驱动主页面状态', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());
      sent.clear();

      // ready → 主页面回发 init。
      await _deliver(tester, {'type': OverlayChannel.typeReady});
      await tester.pump();
      expect(
        sent
            .whereType<Map<Object?, Object?>>()
            .where((m) => m['type'] == OverlayChannel.typeInit),
        hasLength(1),
      );

      // position → 持久化浮窗位置。
      await _deliver(tester, {
        'type': OverlayChannel.typePosition,
        'x': 30,
        'y': 210,
      });
      await tester.pump(const Duration(milliseconds: 100));
      final saved = await repo.loadPreset(overlaySettingsKey);
      expect(saved?['x'], 30.0);
      expect(saved?['y'], 210.0);

      // 缺坐标的 position 被忽略。
      await _deliver(tester, {'type': OverlayChannel.typePosition, 'x': 1});

      // 下一行 / 上一行。
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionNextLine,
      });
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionPrevLine,
      });
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);

      // 开始 / 暂停。
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionTogglePause,
      });
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 锁定后忽略跳转，再解锁。
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionToggleLock,
      });
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsOneWidget);
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionNextLine,
      });
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': OverlayChannel.actionToggleLock,
      });
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsNothing);

      // 未知动作与非法消息不改变状态。
      await _deliver(tester, {
        'type': OverlayChannel.typeControl,
        'action': 'unknown-action',
      });
      await _deliver(tester, 'not-a-map');
      await _deliver(tester, {'type': 'unknown-type'});

      // 浮窗引擎请求关闭。
      await _deliver(tester, {'type': OverlayChannel.typeClose});
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        pluginCalls.any((call) => call.method == 'closeOverlay'),
        isTrue,
      );
    });
  });

  group('阅读交互', () {
    testWidgets('锁定按钮与长按均可锁定，点击角标解锁', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsOneWidget);

      // 锁定后点击舞台不改变状态。
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsOneWidget);

      await tester.tap(find.text('已锁定 · 点击解锁'));
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsNothing);

      // 长按同样进入锁定。
      await tester.longPressAt(const Offset(200, 300));
      await tester.pump();
      expect(find.text('已锁定 · 点击解锁'), findsOneWidget);
      await tester.tap(find.text('已锁定 · 点击解锁'));
      await tester.pump();
    });

    testWidgets('拖动手势改变阅读锚点', (tester) async {
      await setUpView(tester);
      await repo.savePreset(
          'script:s2', const ReaderSettings(fontSize: 24).toJson());
      await mountReader(tester, _sectionDoc());

      expect(find.text('1 / 3'), findsOneWidget);
      await tester.dragFrom(const Offset(200, 400), const Offset(0, -160));
      await tester.pump();
      expect(find.text('1 / 3'), findsNothing);
      expect(find.text('3 / 3'), findsOneWidget);

      await tester.dragFrom(const Offset(200, 400), const Offset(0, 160));
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('速度/字号步进实时生效并保存预设', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.textContaining('1.4'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.textContaining('1.2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.text_increase));
      await tester.pump();
      expect(find.text('48'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.text_decrease));
      await tester.pump();
      expect(find.text('44'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 800));
      final preset = await repo.loadPreset('script:s2');
      expect(preset?['fontSize'], 44);
    });

    testWidgets('回到开头重置进度', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.replay));
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('进度只读展示，不再提供分段跳转对话框', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.text('1 / 3'));
      await _settle(tester);
      expect(find.text('跳转到段落'), findsNothing);
      expect(find.textContaining('第 2 段'), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('空分段台本点击进度无响应', (tester) async {
      await setUpView(tester);
      final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
      final doc = ScriptDocument(
        id: 's3',
        title: '无分段',
        rawText: '唯一一段正文内容',
        sections: const [],
        markers: const [],
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(_reader(db, doc));
      await tester.pump();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });

      // 自动断行后行数随窗口变化，这里只点"当前 / 总数"进度。
      await tester.tap(find.textContaining(RegExp(r'/ \d+')));
      await _settle(tester);
      expect(find.text('跳转到段落'), findsNothing);
    });

    testWidgets('屏幕旋转后按新宽度自动重排', (tester) async {
      await setUpView(tester);
      final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
      final doc = ScriptDocument(
        id: 's5',
        title: '旋转重排',
        rawText: '一二三四五六七八九十' * 6,
        sections: const [],
        markers: const [],
        createdAt: now,
        updatedAt: now,
      );
      await mountReader(tester, doc);

      final portrait = _totalLines(tester);
      expect(portrait, greaterThan(3));

      // 竖屏 400×800 → 横屏 800×400，每行字数变多、总行数变少。
      tester.view.physicalSize = const Size(2400, 1200);
      await tester.pump();
      await _settle(tester);
      final landscape = _totalLines(tester);
      expect(landscape, lessThan(portrait));

      // 转回竖屏应恢复原行数（重建使用同一套公式，结果稳定）。
      tester.view.physicalSize = const Size(1200, 2400);
      await tester.pump();
      await _settle(tester);
      expect(_totalLines(tester), portrait);
    });

    testWidgets('重点标记渲染为富文本', (tester) async {
      await setUpView(tester);
      final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
      final doc = ScriptDocument(
        id: 's4',
        title: '重点标记',
        rawText: '重点词语在这里',
        sections: const [
          ScriptSection(id: 'm1', scriptId: 's4', ord: 0, text: '重点词语在这里'),
        ],
        markers: const [
          ScriptMarker(
            id: 'mk1',
            scriptId: 's4',
            sectionId: 'm1',
            charOffset: 0,
            kind: MarkerKind.emphasis,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(_reader(db, doc));
      await tester.pump();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });
      expect(
        find.byWidgetPredicate(
            (widget) => widget is Text && widget.textSpan != null),
        findsWidgets,
      );
    });

    testWidgets('initialAnchor 超界时夹到最后一行', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc(), initialAnchor: 99);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('全局默认参数在无台本预设时生效', (tester) async {
      await setUpView(tester);
      await repo.setSetting(
        readerDefaultsKey,
        const ReaderSettings(fontSize: 60).toJsonString(),
      );
      await mountReader(tester, _sectionDoc());
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.style?.fontSize == 60,
        ),
        findsWidgets,
      );
    });

    testWidgets('应用生命周期变化不崩溃', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('篇尾行为', () {
    testWidgets('默认停止：读到末行后暂停并显示已到篇尾', (tester) async {
      await setUpView(tester);
      await repo.savePreset(
        'script:s2',
        const ReaderSettings(speed: 10).toJson(),
      );
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const ValueKey('finished-status')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('循环模式：篇尾延时回到篇首并继续运行', (tester) async {
      await setUpView(tester);
      await repo.savePreset(
        'script:s2',
        const ReaderSettings(
          speed: 0.2,
          endBehavior: ReaderEndBehavior.loop,
        ).toJson(),
      );
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      var sawFinished = false;
      for (var i = 0; i < 130; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .byKey(const ValueKey('finished-status'))
            .evaluate()
            .isNotEmpty) {
          sawFinished = true;
        }
      }

      expect(sawFinished, isTrue);
      expect(find.byKey(const ValueKey('finished-status')), findsNothing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });
  });

  group('设置面板与语音入口', () {
    testWidgets('从阅读页打开设置、切换主题并保存为默认', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.tune));
      await _settle(tester);
      expect(find.text('阅读设置'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 800));
      final preset = await repo.loadPreset('script:s2');
      expect(preset?['theme'], ReaderTheme.stageWhite.name);

      // 关闭「跟随延迟补偿」应写回预设。
      await tester.scrollUntilVisible(
        find.text('跟随延迟补偿'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('跟随延迟补偿'));
      await _settle(tester);
      final updated = await repo.loadPreset('script:s2');
      expect(updated?['latencyCompensation'], isFalse);

      await tester.tap(find.text('存为全局默认'));
      await _settle(tester);
      expect(find.text('已存为全局默认阅读参数'), findsOneWidget);
      expect(await repo.getSetting(readerDefaultsKey), isNotNull);

      // 关闭面板。
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      expect(find.text('阅读设置'), findsNothing);
    });

    testWidgets('模型解包失败时回滚状态并给出可重试入口', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      final micButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(IconButton),
        ),
      );
      // 测试环境没有 path_provider 插件，安装将真实失败并被包装成安装异常。
      await tester.runAsync(() async {
        micButton.onPressed!();
        await Future<void>.delayed(const Duration(seconds: 8));
      });
      await tester.pump();
      await _settle(tester);

      expect(find.textContaining('离线模型安装失败'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, '重试'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('准备中…'), findsNothing);
    });

    testWidgets('回放启动失败时提示并停止', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      final replayButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.graphic_eq),
          matching: find.byType(IconButton),
        ),
      );
      await tester.runAsync(() async {
        replayButton.onPressed!();
        await Future<void>.delayed(const Duration(seconds: 8));
      });
      await tester.pump();
      await _settle(tester);

      expect(find.textContaining('离线模型安装失败'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, '重试'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });
  });

  group('局域网遥控', () {
    testWidgets('开启遥控展示二维码，命令按行号推进并可停止服务', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.cast));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('遥控提词'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      final pairingText = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
      final pairing = RemotePairing.tryParse(pairingText);
      expect(pairing, isNotNull);

      await tester.runAsync(() async {
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${pairing!.port}/ws',
        );
        final messages = <Map<String, Object?>>[];
        socket.listen((data) {
          final json = RemoteProtocol.asJsonObject(data);
          if (json != null) messages.add(json);
        });
        socket.add(
          jsonEncode(
            RemoteHello(token: pairing.token, client: 'test').toJson(),
          ),
        );
        for (var i = 0; i < 50 && messages.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(messages.any((item) => item['type'] == 'state'), isTrue);
        final state = messages.firstWhere((item) => item['type'] == 'state');
        expect(state['lineCount'], 3);
        expect(state['lineUnit'], RemoteState.lineUnitParagraph);
        expect(state['anchorRow'], 0);
        expect(state['anchorOffset'], 0);
        expect(state['rowCount'], 3);
        expect(state['anchorRowText'], '第一段内容简短');

        socket.add(
          jsonEncode(
            const RemoteCommand(
              seq: 1,
              action: RemoteProtocol.actionNextLine,
            ).toJson(),
          ),
        );
        for (var i = 0;
            i < 50 && !messages.any((item) => item['type'] == 'ack');
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(messages.any((item) => item['type'] == 'ack'), isTrue);
        await socket.close();
      });
      await _settle(tester);

      expect(find.textContaining('2 / 3'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('停止遥控'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byIcon(Icons.cast), findsOneWidget);
    });
  });

  group('段落化文本', () {
    testWidgets('同段内不按标点断开，只按宽度自然折行', (tester) async {
      final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
      const text = '第一句话说完了。第二句话也说完，第三句话继续补充，'
          '第四句话再延长一些，第五句话让整段足够长以便折行。';
      final doc = ScriptDocument(
        id: 's4',
        title: '整段台本',
        rawText: text,
        sections: const [
          ScriptSection(id: 'sec1', scriptId: 's4', ord: 0, text: text),
        ],
        markers: const [],
        createdAt: now,
        updatedAt: now,
      );
      await setUpView(tester);
      await mountReader(tester, doc);

      // 语义行只有 1 段，但视觉行按宽度折成多行。
      final total = _totalLines(tester);
      expect(total, greaterThan(1));
      expect(find.text('1 / $total'), findsOneWidget);

      // 连续文本渲染：只有语义行，没有分段跳转入口。
      await tester.tap(find.text('1 / $total'));
      await _settle(tester);
      expect(find.text('跳转到段落'), findsNothing);
    });

    testWidgets('遥控状态按段落坐标上报并附带视觉行', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.cast));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // 状态卡在视觉行可用时按 rowProgress 展示，段落语义行仍为 1 / 3。
      expect(find.text('1 / 3'), findsOneWidget);
    });
  });

  group('功能栏隐藏', () {
    testWidgets('隐藏后保留把手可唤出并全局持久化', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());
      const handle = ValueKey('reader-panel-handle');
      expect(find.byKey(handle), findsNothing);

      await tester.tap(find.byTooltip('隐藏功能栏'));
      await tester.pump();
      expect(find.byKey(handle), findsOneWidget);
      expect(await repo.getSetting(readerPanelHiddenKey), '1');

      // 收起状态下重新进入页面仍保持隐藏。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_reader(db, _sectionDoc()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(handle), findsOneWidget);

      await tester.tap(find.byKey(handle));
      await tester.pump();
      expect(find.byKey(handle), findsNothing);
      expect(await repo.getSetting(readerPanelHiddenKey), '0');
    });
  });

  group('外接显示', () {
    testWidgets('无副屏时提示且不发起显示', (tester) async {
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.textContaining('未检测到外接显示器'), findsOneWidget);
      expect(
        displayCalls.where((call) => call.method == 'present'),
        isEmpty,
      );
    });

    testWidgets('单屏直接输出、滚动时更新并可关闭', (tester) async {
      displayList = <Object?>[
        {
          'id': 2,
          'name': 'HDMI Screen',
          'width': 1920,
          'height': 1080,
          'presentation': true,
        },
      ];
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byIcon(Icons.desktop_windows), findsOneWidget);

      final show = displayCalls.singleWhere((call) => call.method == 'present');
      final args = show.arguments as Map<Object?, Object?>;
      expect(args['displayId'], 2);
      expect(args['lines'], ['第一段内容简短', '第二段内容简短', '第三段内容简短']);
      expect(args['anchor'], 0);

      // 下一行后，300 ms 周期定时器把锚点推送到副屏。
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final updates = displayCalls
          .where((call) => call.method == 'update')
          .toList(growable: false);
      expect(updates, isNotEmpty);
      expect(
        (updates.last.arguments as Map<Object?, Object?>)['anchor'],
        1,
      );

      await tester.tap(find.byIcon(Icons.desktop_windows));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        displayCalls.any((call) => call.method == 'dismiss'),
        isTrue,
      );
      expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
    });

    testWidgets('多屏时弹出选择列表', (tester) async {
      displayList = <Object?>[
        {'id': 2, 'name': 'HDMI Screen', 'width': 1920, 'height': 1080},
        {'id': 3, 'name': 'USB Screen', 'width': 1280, 'height': 720},
      ];
      await setUpView(tester);
      await mountReader(tester, _sectionDoc());

      await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('选择外接显示器'), findsOneWidget);

      await tester.tap(find.textContaining('USB Screen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final show = displayCalls.singleWhere((call) => call.method == 'present');
      expect(
        (show.arguments as Map<Object?, Object?>)['displayId'],
        3,
      );
    });
  });
}
