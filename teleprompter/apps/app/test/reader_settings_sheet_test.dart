import 'package:core_alignment/core_alignment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/reader_settings/overlay_settings.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings_sheet.dart';

Widget _host({
  required ReaderSettings settings,
  required ValueChanged<ReaderSettings> onChanged,
  ValueChanged<ReaderSettings>? onSaveAsDefault,
  OverlaySettings? overlaySettings,
  ValueChanged<OverlaySettings>? onOverlayChanged,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showReaderSettingsSheet(
              context: context,
              settings: settings,
              onChanged: onChanged,
              onSaveAsDefault: onSaveAsDefault,
              overlaySettings: overlaySettings,
              onOverlayChanged: onOverlayChanged,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    60,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _sliderFor(WidgetTester tester, String label) {
  final tile =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  return find.descendant(of: tile, matching: find.byType(Slider));
}

Future<void> _dragSlider(WidgetTester tester, String label) async {
  await _scrollTo(tester, label);
  await tester.drag(_sliderFor(tester, label), const Offset(40, 0));
  await tester.pumpAndSettle();
}

Future<void> _tapSwitch(WidgetTester tester, String label) async {
  await _scrollTo(tester, label);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('设置面板渲染全部区块并回传每项修改', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final changes = <ReaderSettings>[];
    final overlayChanges = <OverlaySettings>[];
    ReaderSettings? savedDefault;
    var savedDefaultCount = 0;

    await tester.pumpWidget(
      _host(
        settings: const ReaderSettings(),
        onChanged: changes.add,
        onSaveAsDefault: (settings) {
          savedDefault = settings;
          savedDefaultCount++;
        },
        overlaySettings: const OverlaySettings(),
        onOverlayChanged: overlayChanges.add,
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('视觉'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    // 主题切换。
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    expect(changes.last.theme, ReaderTheme.stageWhite);

    // 按面板从上到下的顺序交互，滚动方向保持单向。
    for (final label in const [
      '字号',
      '行距',
      '左边距',
      '右边距',
    ]) {
      await _dragSlider(tester, label);
    }

    // 每行字数已随段落化文本模型下线，不再提供滑块与只读展示。
    expect(find.text('每行字数（自动）'), findsNothing);

    await _dragSlider(tester, '字距');
    for (final label in const [
      '居中对齐',
      '水平镜像',
      '垂直镜像',
    ]) {
      await _tapSwitch(tester, label);
    }
    for (final label in const [
      '分光镜水平校准',
      '分光镜垂直校准',
      '匀速速度',
    ]) {
      await _dragSlider(tester, label);
    }

    // 速度归零按钮。
    await _scrollTo(tester, '速度归零（1.2 行/秒）');
    await tester.tap(find.text('速度归零（1.2 行/秒）'));
    await tester.pumpAndSettle();
    expect(changes.last.speed, ReaderSettings.defaults.speed);

    for (final label in const [
      '阅读带位置（屏高比例）',
      '平滑度',
    ]) {
      await _dragSlider(tester, label);
    }
    for (final label in const [
      '逐行跟随',
      '跟随延迟补偿',
      '停顿停住',
      '屏幕常亮',
    ]) {
      await _tapSwitch(tester, label);
    }

    // 语音匹配档位：五档可辨，只展示名称与一句用途说明。
    await _scrollTo(tester, '语音匹配宽松度');
    for (final label in const ['最谨慎', '严格', '标准', '宽松', '最宽松']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('默认档位，兼顾跟随速度与稳定。'), findsOneWidget);
    await tester.tap(find.text('宽松'));
    await tester.pumpAndSettle();
    expect(changes.last.matchTolerance, MatchTolerance.loose);
    expect(find.text('环境有噪声或常临场发挥时更容易跟住。'), findsOneWidget);
    await tester.tap(find.text('严格'));
    await tester.pumpAndSettle();
    expect(changes.last.matchTolerance, MatchTolerance.strict);

    // 悬浮窗区块。
    for (final label in const [
      '窗口宽度',
      '不透明度',
    ]) {
      await _dragSlider(tester, label);
    }

    // 悬浮窗可见行数：仅 3 / 5，全稿模式已下线。
    await _scrollTo(tester, '5 行');
    await tester.tap(find.text('5 行'));
    await tester.pumpAndSettle();
    expect(overlayChanges.last.lineCount, 5);
    expect(find.text('全稿'), findsNothing);

    expect(changes.length, greaterThan(20));
    expect(overlayChanges.length, greaterThan(3));

    // 存为全局默认。
    await tester.tap(find.text('存为全局默认'));
    await tester.pumpAndSettle();
    expect(savedDefaultCount, 1);
    expect(savedDefault, isNotNull);

    // 恢复默认。
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(changes.last.toJson(), ReaderSettings.defaults.toJson());
  });

  testWidgets('识别模型默认中文轻量，可切中英混合', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final changes = <ReaderSettings>[];
    await tester.pumpWidget(
      _host(settings: const ReaderSettings(), onChanged: changes.add),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, '识别模型');
    expect(find.text('中英混合'), findsOneWidget);
    expect(find.text('中文轻量'), findsOneWidget);
    expect(find.text('默认，仅中文、占用更小；开箱不支持中英混说。'), findsOneWidget);

    await tester.tap(find.text('中英混合'));
    await tester.pumpAndSettle();
    expect(changes.last.asrModel, AsrModelChoice.bilingualMixed);
    expect(
      find.text('支持中英混说；解包约 209 MB，切换后下次语音跟随生效。'),
      findsOneWidget,
    );
    expect(find.text('切换后于下次开始语音跟随时生效。'), findsOneWidget);
  });

  testWidgets('未传入悬浮窗回调时不渲染悬浮窗区块', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        settings: const ReaderSettings(),
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('悬浮提词'), findsNothing);
    expect(find.text('存为全局默认'), findsNothing);
    expect(find.text('恢复默认'), findsOneWidget);
  });

  testWidgets('面板外部点击可关闭', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        settings: const ReaderSettings(),
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsNothing);
  });
}
