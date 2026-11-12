import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/external_display.dart';

const _channelName = 'tps/display';
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late TestDefaultBinaryMessenger messenger;
  late List<MethodCall> calls;
  Object? listResult;
  Object? Function(MethodCall call)? handler;

  setUp(() {
    channel = const MethodChannel(_channelName);
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    calls = <MethodCall>[];
    listResult = <Object?>[];
    handler = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final custom = handler;
      if (custom != null) return custom(call);
      if (call.method == 'listDisplays') return listResult;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('ExternalDisplay.tryParse', () {
    test('解析合法副屏并保留分辨率', () {
      final display = ExternalDisplay.tryParse({
        'id': 2,
        'name': 'HDMI Screen',
        'width': 1920,
        'height': 1080,
        'presentation': true,
      });
      expect(display, isNotNull);
      expect(display!.id, 2);
      expect(display.name, 'HDMI Screen');
      expect(display.width, 1920);
      expect(display.height, 1080);
      expect(display.presentation, isTrue);
    });

    test('缺 id 返回 null，其余字段用默认值', () {
      expect(ExternalDisplay.tryParse({'name': 'x'}), isNull);
      expect(ExternalDisplay.tryParse('not-a-map'), isNull);
      final display = ExternalDisplay.tryParse({'id': 3});
      expect(display!.name, 'Display 3');
      expect(display.width, 0);
      expect(display.height, 0);
      expect(display.presentation, isTrue);
    });
  });

  group('ExternalDisplayService', () {
    test('枚举副屏并丢弃非法条目', () async {
      listResult = <Object?>[
        {'id': 2, 'name': 'HDMI', 'width': 1920, 'height': 1080},
        {'name': 'no id'},
      ];
      final service = ExternalDisplayService();
      addTearDown(service.dispose);
      final displays = await service.listDisplays();
      expect(displays, hasLength(1));
      expect(displays.single.id, 2);
      expect(calls.single.method, 'listDisplays');
    });

    test('原生未实现或报错时返回空列表', () async {
      handler = (call) => throw PlatformException(code: 'no_impl');
      final service = ExternalDisplayService();
      addTearDown(service.dispose);
      expect(await service.listDisplays(), isEmpty);
    });

    test('show 传递行号、文本、字号、镜像与阅读带位置', () async {
      final service = ExternalDisplayService();
      addTearDown(service.dispose);
      final ok = await service.show(
        displayId: 2,
        lines: const ['第一行', '第二行'],
        anchor: 1,
        fontSize: 48,
        mirrored: true,
        bandRatio: 0.34,
      );
      expect(ok, isTrue);
      final call = calls.singleWhere((item) => item.method == 'present');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['displayId'], 2);
      expect(args['lines'], ['第一行', '第二行']);
      expect(args['anchor'], 1);
      expect(args['fontSize'], 48.0);
      expect(args['mirrored'], isTrue);
      expect(args['bandRatio'] as double, closeTo(0.34, 1e-9));
    });

    test('show 失败返回 false，update/hide 静默吞掉异常', () async {
      handler = (call) => throw PlatformException(code: 'no_impl');
      final service = ExternalDisplayService();
      addTearDown(service.dispose);
      expect(
        await service.show(
          displayId: 2,
          lines: const ['a'],
          anchor: 0,
          fontSize: 40,
          mirrored: false,
        ),
        isFalse,
      );
      await service.update(
        lines: const ['a'],
        anchor: 0,
        fontSize: 40,
        mirrored: false,
      );
      final update = calls
          .singleWhere((call) => call.method == 'update')
          .arguments as Map<Object?, Object?>;
      expect(update['bandRatio'] as double, closeTo(0.5, 1e-9));
      await service.hide();
      expect(
        calls.map((call) => call.method),
        containsAll(<String>['present', 'update', 'dismiss']),
      );
    });

    test('副屏拔出事件通过流下发', () async {
      final service = ExternalDisplayService();
      addTearDown(service.dispose);
      final events = <int>[];
      final sub = service.removedDisplays.listen(events.add);
      addTearDown(sub.cancel);
      await messenger.handlePlatformMessage(
        _channelName,
        _codec.encodeMethodCall(const MethodCall('displayRemoved', 2)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, [2]);
    });

    test('dispose 后不再派发拔出事件', () async {
      final service = ExternalDisplayService();
      final events = <int>[];
      service.removedDisplays.listen(events.add);
      service.dispose();
      await messenger.handlePlatformMessage(
        _channelName,
        _codec.encodeMethodCall(const MethodCall('displayRemoved', 5)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });
  });
}
