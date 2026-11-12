import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:teleprompter/features/remote/scan_page.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/remote/remote_protocol.dart';

const _pairing = 'tps://pair?host=192.168.1.10&port=7788&token=abc123';

Widget _host(ScannerBuilder builder, ValueChanged<RemotePairing?> onResult) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<RemotePairing>(
            MaterialPageRoute<RemotePairing>(
              builder: (_) => ScanPage(scannerBuilder: builder),
            ),
          );
          onResult(result);
        },
        child: const Text('open'),
      ),
    ),
  );
}

ScannerBuilder _fakeScanner(String Function() raw) {
  return (context, onDetect) => Center(
        child: TextButton(
          onPressed: () => onDetect(raw()),
          child: const Text('模拟扫码'),
        ),
      );
}

Widget _l10nHost(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('扫到配对串后返回并关闭页面', (tester) async {
    RemotePairing? result;
    await tester.pumpWidget(
      _host(_fakeScanner(() => _pairing), (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('对准主控端阅读页的二维码'), findsOneWidget);

    await tester.tap(find.text('模拟扫码'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.token, 'abc123');
    expect(result!.host, '192.168.1.10');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('非配对二维码提示并保持扫码页', (tester) async {
    RemotePairing? result;
    await tester.pumpWidget(
      _host(
          _fakeScanner(() => 'https://example.com'), (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模拟扫码'));
    await tester.pumpAndSettle();
    expect(find.text('不是大皖提词器配对二维码'), findsOneWidget);
    expect(result, isNull);
    expect(find.byType(ScanPage), findsOneWidget);
  });

  testWidgets('返回粘贴输入时结果为 null', (tester) async {
    RemotePairing? result;
    await tester.pumpWidget(
      _host(_fakeScanner(() => _pairing), (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('改为粘贴配对串'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(ScanPage), findsNothing);
  });

  testWidgets('相机权限被拒绝时展示降级说明', (tester) async {
    await tester.pumpWidget(
      _l10nHost(
        const ScanPermissionFallback(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      ),
    );
    expect(find.textContaining('相机权限被拒绝'), findsOneWidget);
    expect(find.byIcon(Icons.no_photography), findsOneWidget);
  });

  testWidgets('相机不可用（非权限）展示通用说明', (tester) async {
    await tester.pumpWidget(
      _l10nHost(
        const ScanPermissionFallback(
          errorCode: MobileScannerErrorCode.genericError,
        ),
      ),
    );
    expect(find.textContaining('相机不可用'), findsOneWidget);
  });

  test('Windows 不支持相机扫码', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(supportsQrScanning, isFalse);
  });

  test('Android/macOS 支持相机扫码', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(supportsQrScanning, isTrue, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
