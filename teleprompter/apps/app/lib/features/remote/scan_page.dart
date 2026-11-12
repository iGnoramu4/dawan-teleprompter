import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/remote/remote_protocol.dart';

/// 扫码结果构造器：测试注入 fake，避免在宿主环境启动相机。
typedef ScannerBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onDetect,
);

/// 扫描配对二维码（E6-2 补充）：成功返回 [RemotePairing]，取消返回 null。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.scannerBuilder});

  final ScannerBuilder? scannerBuilder;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _handled = false;

  void _onDetect(String raw) {
    if (_handled) return;
    final pairing = RemotePairing.tryParse(raw);
    if (pairing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).remoteScanNotPairing),
        ),
      );
      return;
    }
    _handled = true;
    Navigator.of(context).pop(pairing);
  }

  Widget _buildScanner(BuildContext context, ValueChanged<String> onDetect) {
    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) {
            onDetect(raw);
            break;
          }
        }
      },
      // 相机不可用（未授权/无相机/被占用）时显式降级为粘贴输入。
      errorBuilder: (context, error) =>
          ScanPermissionFallback(errorCode: error.errorCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final builder = widget.scannerBuilder ?? _buildScanner;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.remoteScanTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: builder(context, _onDetect)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.remoteScanHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    label: Text(
                      l10n.remoteScanBack,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 相机不可用时的占位视图：说明权限被拒绝并引导回粘贴输入。
class ScanPermissionFallback extends StatelessWidget {
  const ScanPermissionFallback({super.key, required this.errorCode});

  final MobileScannerErrorCode errorCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permissionDenied =
        errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              permissionDenied
                  ? l10n.remoteScanPermissionDenied
                  : l10n.remoteScanFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// 当前平台是否具备相机扫码能力；Windows/Linux 无插件实现。
bool get supportsQrScanning =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
