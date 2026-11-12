import 'package:data_store/data_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/overlay/overlay_window_service.dart';
import 'package:teleprompter/shared/reader_settings/overlay_settings.dart';

const _pluginChannel = MethodChannel('x-slayer/overlay_channel');
const _overlayChannel = MethodChannel('x-slayer/overlay');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScriptRepository repository;
  late OverlayWindowService service;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    db = AppDatabase.memory();
    repository = ScriptRepository(db);
    service = OverlayWindowService(repository);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pluginChannel, null);
    messenger.setMockMethodCallHandler(_overlayChannel, null);
    await db.close();
  });

  void mockPlugin(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(_pluginChannel, handler);
  }

  test('无预设时返回默认参数', () async {
    expect(await service.loadSettings(), OverlaySettings.defaults);
  });

  test('预设可往返读写并归一化', () async {
    await service.saveSettings(
      const OverlaySettings(widthDp: 10000, opacity: 2, lineCount: 7),
    );
    final loaded = await service.loadSettings();
    expect(loaded.widthDp, 1200);
    expect(loaded.opacity, 1.0);
    expect(loaded.lineCount, 5);
    expect(loaded.fontSize, 24);
  });

  test('预设 JSON 损坏时回退默认参数', () async {
    await repository.savePreset(overlaySettingsKey, {
      'widthDp': 'broken',
      'opacity': 'broken',
    });
    expect(await service.loadSettings(), OverlaySettings.defaults);
  });

  test('位置参数按设备像素比换算，缺位置时不传 startPosition', () async {
    final calls = <MethodCall>[];
    mockPlugin((call) async {
      calls.add(call);
      return true;
    });

    await service.show(
      settings: const OverlaySettings(
        lineCount: 5,
        x: 40,
        y: 120,
      ),
      title: '悬浮稿',
      devicePixelRatio: 2.5,
    );
    final withPosition = calls.single.arguments as Map<Object?, Object?>;
    expect(withPosition['width'], 900);
    expect(withPosition['height'], 1050);
    expect(withPosition['enableDrag'], true);
    expect(withPosition['overlayTitle'], '悬浮稿');
    expect(withPosition['overlayContent'], '悬浮稿');
    final start = withPosition['startPosition'] as Map<Object?, Object?>;
    expect(start['x'], 100);
    expect(start['y'], 300);

    calls.clear();
    await service.show(
      settings: const OverlaySettings(),
      title: '无位置',
      devicePixelRatio: 1,
    );
    final noPosition = calls.single.arguments as Map<Object?, Object?>;
    expect(noPosition['startPosition'], isNull);
  });

  test('权限查询走插件通道', () async {
    mockPlugin((call) async => call.method == 'checkPermission' ? true : null);
    expect(await service.isPermissionGranted(), isTrue);

    mockPlugin((call) async => call.method == 'checkPermission' ? false : null);
    expect(await service.isPermissionGranted(), isFalse);

    // 插件层吞掉通道异常并回退为未授权。
    mockPlugin((call) async => throw PlatformException(code: 'boom'));
    expect(await service.isPermissionGranted(), isFalse);
  });

  test('请求权限后再次确认，兼容不返回结果的 ROM', () async {
    mockPlugin((call) async {
      if (call.method == 'requestPermission') return true;
      return null;
    });
    expect(await service.requestPermission(), isTrue);

    // 系统页返回 false，但再次查询已授予。
    mockPlugin((call) async {
      if (call.method == 'requestPermission') return false;
      if (call.method == 'checkPermission') return true;
      return null;
    });
    expect(await service.requestPermission(), isTrue);

    // 系统页返回 false 且仍未授予。
    mockPlugin((call) async => false);
    expect(await service.requestPermission(), isFalse);
  });

  test('活动状态与关闭走插件通道', () async {
    mockPlugin((call) async => call.method == 'isOverlayActive');
    expect(await service.isActive(), isTrue);

    mockPlugin((call) async {
      expect(call.method, 'closeOverlay');
      return null;
    });
    await service.close();
  });

  test('位置读取成功与失败', () async {
    mockPlugin((call) async {
      if (call.method == 'getOverlayPosition') {
        return {'x': 12.0, 'y': 340.0};
      }
      return null;
    });
    final position = await service.currentPosition();
    expect(position?.x, 12.0);
    expect(position?.y, 340.0);

    mockPlugin((call) async => throw PlatformException(code: 'gone'));
    expect(await service.currentPosition(), isNull);
  });
}
