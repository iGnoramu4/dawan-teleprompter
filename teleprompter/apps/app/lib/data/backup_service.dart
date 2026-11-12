import 'dart:io';

import 'package:data_store/data_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 一份本地自动备份。
class BackupInfo {
  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
  });

  final File file;
  final DateTime createdAt;
  final int sizeBytes;

  String get path => file.path;

  String get name => p.basename(file.path);
}

/// 每日自动备份（应用私有目录 `backups/`）：写入最新全量 `.tps`，保留最近 [keep] 份。
class BackupService {
  BackupService(
    this._repository, {
    this.keep = 7,
    Directory? root,
    DateTime Function()? clock,
  })  : _root = root,
        _clock = clock;

  final ScriptRepository _repository;
  final int keep;

  /// 可注入根目录以便测试；为空时用应用文档目录。
  final Directory? _root;

  /// 可注入时钟以便测试每日判定。
  final DateTime Function()? _clock;

  DateTime get _now => (_clock ?? DateTime.now)();

  static final RegExp _namePattern = RegExp(r'^teleprompter-(\d{8})\.tps$');

  Future<Directory> _backupDir() async {
    final root = _root ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'backups'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 今天尚未备份时生成一份；已有今日备份则返回 null。
  Future<BackupInfo?> backupIfDue() async {
    final existing = await list();
    final today = _stamp(_now);
    for (final item in existing) {
      if (_stampOf(item.name) == today) return null;
    }
    return backupNow();
  }

  /// 立即备份（同日覆盖）；无台本时返回 null。
  Future<BackupInfo?> backupNow() async {
    final bundle = await _repository.exportBundle();
    if (bundle == null) return null;
    final dir = await _backupDir();
    final now = _now;
    final file = File(p.join(dir.path, 'teleprompter-${_stamp(now)}.tps'));
    await file.writeAsString(bundle.encode(), flush: true);
    await _prune();
    final stat = file.statSync();
    return BackupInfo(
      file: file,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  /// 备份列表，按时间从新到旧。
  Future<List<BackupInfo>> list() async {
    final dir = await _backupDir();
    if (!dir.existsSync()) return const [];
    final items = <({String stamp, BackupInfo info})>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final stamp = _stampOf(name);
      if (stamp == null) continue;
      final stat = entity.statSync();
      items.add((
        stamp: stamp,
        info: BackupInfo(
          file: entity,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      ));
    }
    items.sort((a, b) => b.stamp.compareTo(a.stamp));
    return [for (final item in items) item.info];
  }

  /// 最近一份备份。
  Future<BackupInfo?> latest() async {
    final items = await list();
    return items.isEmpty ? null : items.first;
  }

  Future<void> _prune() async {
    final items = await list();
    for (var i = keep; i < items.length; i++) {
      try {
        await items[i].file.delete();
      } on FileSystemException {
        // 单个文件删除失败不影响本次备份。
      }
    }
  }

  String _stamp(DateTime time) => '${time.year.toString().padLeft(4, '0')}'
      '${time.month.toString().padLeft(2, '0')}'
      '${time.day.toString().padLeft(2, '0')}';

  String? _stampOf(String name) => _namePattern.firstMatch(name)?.group(1);
}
