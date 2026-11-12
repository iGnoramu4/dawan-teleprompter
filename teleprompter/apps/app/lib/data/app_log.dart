import 'dart:convert';
import 'dart:io';

/// 本地 JSONL 运行日志（M1-c）：每行一个 JSON 对象，便于导出排查。
///
/// 日志写入不阻塞 UI：`event` 仅做编码与 `IOSink.writeln`，
/// 失败时静默降级（日志不能影响提词）。
class AppLog {
  AppLog._();

  static final AppLog instance = AppLog._();

  IOSink? _sink;
  String? _filePath;

  final List<String> _recent = <String>[];
  static const int _recentLimit = 200;

  bool get enabled => _sink != null;
  String? get filePath => _filePath;
  List<String> get recent => List.unmodifiable(_recent);

  Future<void> init(Directory directory) async {
    try {
      await directory.create(recursive: true);
      final path = '${directory.path}/app-${_dateKey(DateTime.now())}.jsonl';
      _sink = File(path).openWrite(mode: FileMode.append);
      _filePath = path;
      // 不记录本地路径（CODING §7）。
      event('app', 'log_started');
    } catch (_) {
      // 日志不可用时静默降级，不影响主流程。
    }
  }

  /// 写入一条事件。`data` 只能是 JSON 可编码的基础类型。
  void event(
    String tag,
    String name, [
    Map<String, Object?> data = const <String, Object?>{},
  ]) {
    final record = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'tag': tag,
      'event': name,
      if (data.isNotEmpty) ...data,
    };
    final line = jsonEncode(record);
    _recent.add(line);
    if (_recent.length > _recentLimit) _recent.removeAt(0);
    try {
      _sink?.writeln(line);
    } catch (_) {
      // 磁盘写入失败时静默丢弃，日志不得影响提词。
    }
  }

  /// 读取当日日志文件内容（导出用）。
  Future<String> readAll() async {
    final path = _filePath;
    if (path == null) return '';
    try {
      final file = File(path);
      if (!file.existsSync()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  String get directoryPath => _filePath ?? '';

  static String _dateKey(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}';
  }
}
