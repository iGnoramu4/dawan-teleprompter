import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 录制文件管理：默认放在应用文档目录的 `recordings/` 下（与数据库、日志同级）。
class RecordingStore {
  RecordingStore({Directory? root}) : _root = root;

  final Directory? _root;

  Future<Directory> ensureRoot() async {
    final root = _root ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'recordings'),
        );
    if (!root.existsSync()) await root.create(recursive: true);
    return root;
  }

  Future<String> newAudioPath(String id) async {
    final root = await ensureRoot();
    return p.join(root.path, '$id.wav');
  }

  /// 生成不重复的录制 id（时间戳 + 进程内序号，避免引入额外依赖）。
  static String newId([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final suffix = DateTime.now().microsecondsSinceEpoch % 1000;
    return 'rec-$now-${suffix.toString().padLeft(3, '0')}';
  }

  static Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 文件不存在或已被删除时忽略。
    }
  }
}
