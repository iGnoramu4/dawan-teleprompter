import 'dart:io';

/// 第三方依赖许可扫描（E16-2 / ADR-0003）。
///
/// 规则：
/// 1. 扫描仓库内所有 `pubspec.lock`，跳过 SDK / 本地 path / git 依赖；
/// 2. 在 pub 缓存中查找 `LICENSE*` / `COPYING*`，按文本识别许可类型；
/// 3. 仅允许 Apache-2.0 / MIT / BSD-2/3-Clause / ISC / Zlib / Unlicense；
/// 4. 遇到 GPL/LGPL/MPL/未知/缺失许可即失败，退出码 1。
///
/// 用法：`dart run tool/license_scan.dart`
void main() {
  final root = Directory.current;
  final locks = _lockFiles(root);
  if (locks.isEmpty) {
    stderr.writeln('license_scan: 未找到 pubspec.lock');
    exitCode = 1;
    return;
  }

  final cache = _pubCache();
  final packages = <String, _Package>{};
  final ignored = _ignoredPackages();

  for (final lock in locks) {
    for (final pkg in _parseLock(lock)) {
      packages.putIfAbsent('${pkg.name}@${pkg.version}', () => pkg);
    }
  }

  final allowed = <String, int>{};
  final conflicts = <String>[];
  var skipped = 0;
  for (final pkg in packages.values) {
    if (ignored.contains(pkg.name)) {
      skipped += 1;
      continue;
    }
    final license = _detectLicense(cache, pkg);
    if (license.isAllowed) {
      allowed[license.label] = (allowed[license.label] ?? 0) + 1;
    } else {
      conflicts.add(
        '${pkg.name} ${pkg.version}: ${license.label}'
        '${license.detail == null ? '' : ' (${license.detail})'}',
      );
    }
  }

  stdout.writeln(
    'license_scan: ${locks.length} 个 lock 文件，'
    '${packages.length} 个第三方包',
  );
  if (skipped > 0) {
    stdout.writeln(
      '  跳过 $skipped 个仅 Linux 依赖（见 tool/license_scan_ignores.txt）',
    );
  }
  final labels = allowed.keys.toList()..sort();
  for (final label in labels) {
    stdout.writeln('  $label: ${allowed[label]}');
  }
  if (conflicts.isEmpty) {
    stdout.writeln('license_scan: OK');
    return;
  }
  stdout.writeln('license_scan: ${conflicts.length} 个冲突');
  for (final conflict in conflicts) {
    stdout.writeln('  - $conflict');
  }
  exitCode = 1;
}

class _Package {
  _Package(this.name, this.version);

  final String name;
  final String version;
}

class _License {
  const _License(this.label, {this.isAllowed = false, this.detail});

  final String label;
  final bool isAllowed;
  final String? detail;
}

List<File> _lockFiles(Directory root) {
  final result = <File>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('pubspec.lock')) {
      final relative = entity.path.substring(root.path.length);
      if (relative.contains('/.dart_tool/')) continue;
      result.add(entity);
    }
  }
  result.sort((a, b) => a.path.compareTo(b.path));
  return result;
}

Directory _pubCache() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) return Directory(env);
  final home = Platform.environment['HOME'] ?? '';
  return Directory('$home/.pub-cache');
}

/// 读取仅 Linux 依赖的忽略清单；每行 `包名`，`#` 后为原因。
Set<String> _ignoredPackages() {
  final file = File('tool/license_scan_ignores.txt');
  if (!file.existsSync()) return const <String>{};
  final result = <String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final name = trimmed.split(RegExp(r'\s+')).first;
    if (name.isNotEmpty) result.add(name);
  }
  return result;
}

/// 解析 pubspec.lock 的 `packages:` 段：2 空格为包名，4 空格读取 version/source。
List<_Package> _parseLock(File lock) {
  final result = <_Package>[];
  final lines = lock.readAsLinesSync();
  var inPackages = false;
  String? name;
  String? version;
  String? source;

  void flush() {
    if (name != null && version != null && source == 'hosted') {
      result.add(_Package(name!, version!));
    }
    name = null;
    version = null;
    source = null;
  }

  for (final line in lines) {
    if (!inPackages) {
      if (line == 'packages:') inPackages = true;
      continue;
    }
    if (line.isNotEmpty && !line.startsWith(' ')) {
      flush();
      inPackages = false;
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    if (indent == 2 && line.trimRight().endsWith(':')) {
      flush();
      name = line.trim().substring(0, line.trim().length - 1);
    } else if (indent == 4) {
      final trimmed = line.trim();
      if (trimmed.startsWith('version:')) {
        version = _unquote(trimmed.substring('version:'.length).trim());
      } else if (trimmed.startsWith('source:')) {
        source = _unquote(trimmed.substring('source:'.length).trim());
      }
    }
  }
  flush();
  return result;
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value.codeUnitAt(0);
    final last = value.codeUnitAt(value.length - 1);
    const doubleQuote = 0x22;
    const singleQuote = 0x27;
    if ((first == doubleQuote && last == doubleQuote) ||
        (first == singleQuote && last == singleQuote)) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

_License _detectLicense(Directory cache, _Package pkg) {
  final dir = Directory(
    '${cache.path}/hosted/pub.dev/${pkg.name}-${pkg.version}',
  );
  if (!dir.existsSync()) {
    return _License('未在 pub 缓存中找到（${dir.path}）');
  }
  final files = dir.listSync().whereType<File>().where((file) {
    final name = file.uri.pathSegments.last.toUpperCase();
    return name == 'LICENSE' ||
        name == 'LICENSE.MD' ||
        name.startsWith('LICENSE-') ||
        name.startsWith('LICENSE.');
  }).toList();
  if (files.isEmpty) {
    final copying = dir.listSync().whereType<File>().where((file) {
      final name = file.uri.pathSegments.last.toUpperCase();
      return name == 'COPYING' || name.startsWith('COPYING.');
    }).toList();
    files.addAll(copying);
  }
  if (files.isEmpty) return const _License('缺少许可文件');

  final labels = <_License>[];
  for (final file in files) {
    labels.add(_classify(file.readAsStringSync()));
  }
  final allowed = labels.where((license) => license.isAllowed).toList();
  if (allowed.isNotEmpty) {
    return _License(
      allowed.map((license) => license.label).toSet().join(' / '),
      isAllowed: true,
    );
  }
  return labels.first;
}

_License _classify(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('apache license') ||
      text.contains('apache-2.0') ||
      text.contains('licensed under the apache license')) {
    return const _License('Apache-2.0', isAllowed: true);
  }
  if (text.contains('mit license') ||
      text.contains('permission is hereby granted, free of charge')) {
    return const _License('MIT', isAllowed: true);
  }
  if (text.contains('redistribution and use in source and binary forms')) {
    final hasThirdClause =
        text.contains('neither the name') ||
        text.contains('3. neither the name');
    return _License(
      hasThirdClause ? 'BSD-3-Clause' : 'BSD-2-Clause',
      isAllowed: true,
    );
  }
  if (text.contains('permission to use, copy, modify, and/or distribute') ||
      text.contains('isc license')) {
    return const _License('ISC', isAllowed: true);
  }
  if (text.contains('zlib license') ||
      text.contains("this software is provided 'as-is'") ||
      text.contains('this software is provided “as-is”')) {
    return const _License('Zlib', isAllowed: true);
  }
  if (text.contains(
    'free and unencumbered software released into the '
    'public domain',
  )) {
    return const _License('Unlicense', isAllowed: true);
  }
  if (text.contains('gnu general public license') ||
      text.contains('gnu lesser general public license') ||
      text.contains('mozilla public license') ||
      text.contains('eclipse public license')) {
    return const _License('禁止的 copyleft 许可');
  }
  return const _License('未知许可', detail: '需人工复核');
}
