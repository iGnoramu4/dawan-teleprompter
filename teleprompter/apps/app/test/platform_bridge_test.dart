import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/platform_bridge.dart';

const _channel = MethodChannel('com.tp.prompter.teleprompter/platform');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(_channel, handler);
  }

  test('通知权限：平台返回结果直接透传', () async {
    mock((call) async => call.method == 'notificationStatus' ? false : null);
    expect(await PlatformBridge.notificationGranted(), isFalse);

    mock((call) async => true);
    expect(await PlatformBridge.requestNotification(), isTrue);

    mock((call) async => false);
    expect(await PlatformBridge.requestNotification(), isFalse);
  });

  test('通知权限：通道不可用时按已授予/未授予降级', () async {
    mock((call) async => null);
    expect(await PlatformBridge.notificationGranted(), isTrue);
    expect(await PlatformBridge.requestNotification(), isFalse);

    mock((call) async => throw PlatformException(code: 'missing'));
    expect(await PlatformBridge.notificationGranted(), isTrue);
    expect(await PlatformBridge.requestNotification(), isFalse);
  });

  test('前台服务启动/停止异常被静默忽略', () async {
    mock((call) async {
      expect(
        call.method,
        anyOf('startVoiceService', 'stopVoiceService'),
      );
      return null;
    });
    await PlatformBridge.startVoiceService();
    await PlatformBridge.stopVoiceService();

    mock((call) async => throw PlatformException(code: 'unsupported'));
    await PlatformBridge.startVoiceService();
    await PlatformBridge.stopVoiceService();
  });
}
