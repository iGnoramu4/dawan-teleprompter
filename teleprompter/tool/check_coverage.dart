import 'dart:io';

/// 覆盖率检查（TESTING.md §3）。
///
/// 用法：
///   flutter test --coverage
///   dart run tool/check_coverage.dart --min 60 --core-min 85
///
/// 说明：默认只读取 `apps/app/coverage/lcov.info`；可用 `--lcov a,b,c`
/// 显式指定多个 lcov 文件以合并核心包覆盖率。
void main(List<String> args) {
  final minOverall = _intArg(args, '--min', 70);
  final minCore = _intArg(args, '--core-min', 85);
  final explicitPaths = _listArg(args, '--lcov');
  final paths = explicitPaths != null ? explicitPaths : _discoverLcovFiles();

  final records = <_FileCoverage>[];
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('check_coverage: 找不到 $path');
      exitCode = 1;
      return;
    }
    records.addAll(
      _parseLcov(file.readAsStringSync())
      // 生成代码不计入覆盖率（TESTING.md：生成代码不要求写测试）。
      .where((record) => !_isGenerated(record.path)),
    );
  }

  if (records.isEmpty) {
    stderr.writeln('check_coverage: lcov 中没有可统计的文件');
    exitCode = 1;
    return;
  }

  final groups = <String, List<_FileCoverage>>{};
  for (final record in records) {
    groups.putIfAbsent(_groupOf(record.path), () => []).add(record);
  }

  var failed = false;
  stdout.writeln('check_coverage: ${records.length} 个文件');
  final sorted = groups.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in sorted) {
    final found = _sum(entry.value);
    final hit = entry.value.fold<int>(0, (s, r) => s + r.linesHit);
    final percent = found == 0 ? 100.0 : (hit * 100.0 / found);
    final required = entry.key.startsWith('core_') ? minCore : minOverall;
    final status = percent >= required ? 'OK' : 'FAIL';
    stdout.writeln(
      '  [${entry.key}] ${percent.toStringAsFixed(1)}% '
      '($hit/$found 行, 要求 >= $required%) $status',
    );
    if (percent < required) failed = true;
  }

  if (failed) {
    stderr.writeln('check_coverage: 未达标');
    exitCode = 1;
    return;
  }
  stdout.writeln('check_coverage: OK');
}

/// 生成代码（如 `flutter gen-l10n` 产物）不参与覆盖率统计。
bool _isGenerated(String path) =>
    path.contains('/l10n/generated/') || path.contains('.g.dart');

int _sum(List<_FileCoverage> records) =>
    records.fold<int>(0, (sum, record) => sum + record.linesFound);

/// 从 SF 路径推断归属：`packages/core_alignment/...` 或 `apps/app/...`。
String _groupOf(String path) {
  final package = RegExp(r'packages/([^/]+)/').firstMatch(path);
  if (package != null) return package.group(1)!;
  return 'app';
}

List<_FileCoverage> _parseLcov(String content) {
  final records = <_FileCoverage>[];
  String? path;
  var found = 0;
  var hit = 0;
  for (final line in content.split('\n')) {
    if (line.startsWith('SF:')) {
      path = line.substring(3).trim();
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line == 'end_of_record') {
      if (path != null) {
        records.add(
          _FileCoverage(path: path, linesFound: found, linesHit: hit),
        );
      }
      path = null;
    }
  }
  return records;
}

List<String> _discoverLcovFiles() {
  final candidates = [
    'coverage/lcov.info',
    'apps/app/coverage/lcov.info',
    'packages/core_models/coverage/lcov.info',
    'packages/core_alignment/coverage/lcov.info',
    'packages/core_scroll/coverage/lcov.info',
    'packages/core_reader_layout/coverage/lcov.info',
    'packages/data_store/coverage/lcov.info',
  ];
  final existing = candidates.where((path) => File(path).existsSync()).toList();
  return existing.isEmpty ? ['coverage/lcov.info'] : existing;
}

int _intArg(List<String> args, String name, int fallback) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return fallback;
  return int.tryParse(args[index + 1]) ?? fallback;
}

List<String>? _listArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1].split(',').where((s) => s.isNotEmpty).toList();
}

class _FileCoverage {
  const _FileCoverage({
    required this.path,
    required this.linesFound,
    required this.linesHit,
  });

  final String path;
  final int linesFound;
  final int linesHit;
}
