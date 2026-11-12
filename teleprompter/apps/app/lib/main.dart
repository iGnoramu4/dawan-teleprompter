import 'dart:async';
import 'dart:io';

import 'package:data_store/data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/teleprompter_app.dart';
import 'data/app_log.dart';
import 'data/appearance_settings.dart';
import 'data/backup_service.dart';
import 'data/providers.dart';
import 'data/seed_scripts.dart';
import 'features/reader/overlay/overlay_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PDF 导入直接调用引擎 API，需在使用前初始化一次。
  await pdfrxFlutterInitialize();

  final directory = await getApplicationDocumentsDirectory();
  await AppLog.instance.init(Directory(p.join(directory.path, 'logs')));
  AppLog.instance.event('app', 'launch', {
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystemVersion,
  });
  final db = AppDatabase.openFile(
    File(p.join(directory.path, 'teleprompter.sqlite')),
  );
  final repository = ScriptRepository(db);
  final appearance = await loadAppearanceSettings(repository);
  try {
    await repository.purgeExpiredTrash();
    await repository.seedIfNeeded(await loadSeedScripts());
  } catch (error) {
    // 只记录错误类型，不含堆栈与路径（CODING §7）。
    AppLog.instance.event('db', 'init_failed', {
      'error': error.runtimeType.toString(),
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appearanceProvider.overrideWith((ref) => appearance),
      ],
      child: const TeleprompterApp(),
    ),
  );

  unawaited(_runDailyBackup(repository));
}

/// 悬浮提词窗口入口：由 `flutter_overlay_window` 在独立 FlutterEngine 中调用。
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReaderOverlayApp());
}

/// 每日首次启动写入一份全量备份；失败只记录类型，不影响提词。
Future<void> _runDailyBackup(ScriptRepository repository) async {
  try {
    final backup = await BackupService(repository).backupIfDue();
    if (backup != null) {
      AppLog.instance.event('backup', 'daily_created', {
        'bytes': backup.sizeBytes,
      });
    }
  } catch (error) {
    AppLog.instance.event('backup', 'failed', {
      'error': error.runtimeType.toString(),
    });
  }
}
