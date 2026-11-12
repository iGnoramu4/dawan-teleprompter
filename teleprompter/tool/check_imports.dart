import 'dart:io';

/// 分层依赖检查（ARCHITECTURE.md / CODING.md §4）。
///
/// 规则：
/// 1. `core_models` / `core_alignment` / `core_scroll` 不得依赖 Flutter 或 `dart:ui`；
/// 2. `features/<a>` 不得 import `features/<b>`（跨 feature 必须下沉到 `packages/` 或 `shared/`）；
/// 3. `shared/` 不得反向 import `features/`；
/// 4. `packages/` 不得 import 应用代码（`package:teleprompter/` 或跳出包的相对路径）；
/// 5. `design_system` 不得 import 业务包（`data_store`、`asr_kit` 等）。
void main() {
  final root = Directory.current;
  final violations = <String>[];

  final appLib = Directory('${root.path}/apps/app/lib');
  final packageDirs = _packageDirs(root);

  if (appLib.existsSync()) {
    for (final file in _dartFiles(appLib)) {
      final relative = _relative(root, file);
      for (final import in _imports(file)) {
        if (import.startsWith('package:flutter/') ||
            import == 'dart:ui' ||
            import.startsWith('dart:ui')) {
          continue;
        }
        final sourceFeature = _featureOf(relative);
        if (sourceFeature != null) {
          final targetFeature = _featureOfImport(import, relative);
          if (targetFeature != null && targetFeature != sourceFeature) {
            violations.add(
              '$relative: features/$sourceFeature imports '
              'features/$targetFeature ($import)',
            );
          }
        }
        if (relative.startsWith('lib/shared/') &&
            _featureOfImport(import, relative) != null) {
          violations.add('$relative: shared 不得反向依赖 features ($import)');
        }
      }
    }
  }

  for (final packageDir in packageDirs) {
    final name = packageDir.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final lib = Directory('${packageDir.path}/lib');
    if (!lib.existsSync()) continue;
    for (final file in _dartFiles(lib)) {
      final relative = _relative(packageDir, file);
      for (final import in _imports(file)) {
        if (name.startsWith('core_') &&
            (import.startsWith('package:flutter/') ||
                import.startsWith('dart:ui'))) {
          violations.add('$name/$relative: core 包不得依赖 Flutter/UI ($import)');
        }
        if (import.startsWith('package:teleprompter/')) {
          violations.add('$name/$relative: 包不得依赖应用代码 ($import)');
        }
        if (relative.startsWith('lib/') && import.startsWith('../')) {
          violations.add('$name/$relative: 包内相对路径不得跳出 lib ($import)');
        }
        if (name == 'design_system' &&
            (import.startsWith('package:data_store/') ||
                import.startsWith('package:asr_kit/') ||
                import.startsWith('package:core_alignment/') ||
                import.startsWith('package:core_scroll/') ||
                import.startsWith('package:core_models/'))) {
          violations.add('$name/$relative: design_system 不得依赖业务包 ($import)');
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_imports: OK');
    return;
  }
  stderr.writeln('check_imports: ${violations.length} 处违规');
  for (final violation in violations) {
    stderr.writeln('  - $violation');
  }
  exitCode = 1;
}

List<Directory> _packageDirs(Directory root) {
  final dir = Directory('${root.path}/packages');
  if (!dir.existsSync()) return const [];
  return dir.listSync().whereType<Directory>().toList();
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

Iterable<String> _imports(File file) {
  final pattern = RegExp(
    r'''^\s*(?:import|export|part)\s+(?:'([^']+)'|"([^"]+)")''',
    multiLine: true,
  );
  return pattern
      .allMatches(file.readAsStringSync())
      .map((match) => match.group(1) ?? match.group(2) ?? '');
}

String _relative(Directory root, File file) =>
    file.path.replaceFirst('${root.path}/', '');

String? _featureOf(String relative) {
  final match = RegExp(r'lib/features/([^/]+)/').firstMatch(relative);
  return match?.group(1);
}

/// 解析 import 指向的 feature；相对导入按文件所在目录归一化。
String? _featureOfImport(String import, String relativeFile) {
  if (import.startsWith('package:teleprompter/features/')) {
    return import
        .substring('package:teleprompter/features/'.length)
        .split('/')
        .first;
  }
  if (import.startsWith('package:teleprompter')) return null;
  if (!import.startsWith('.')) return null;

  final fileDir = relativeFile.substring(0, relativeFile.lastIndexOf('/'));
  final normalized = _normalize('$fileDir/$import');
  final match = RegExp(r'lib/features/([^/]+)/').firstMatch(normalized);
  return match?.group(1);
}

String _normalize(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  return parts.join('/');
}
