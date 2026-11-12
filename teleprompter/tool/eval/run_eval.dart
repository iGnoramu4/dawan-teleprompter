import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'lib/run_set.dart';

/// 评测入口（宿主或真机 Flutter harness 共用 `lib/run_set.dart`）：
/// ```
/// flutter pub get
/// dart run run_eval.dart --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8
/// ```
Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('model-dir', help: '模型目录（含 encoder/decoder/joiner/tokens）')
    ..addOption('set', defaultsTo: '../../eval', help: '评测集目录（含 manifest.json）')
    ..addOption('out', defaultsTo: '../../build/eval-report.json')
    ..addOption('label', defaultsTo: 'host', help: '运行环境标识')
    ..addOption('chunk-ms', defaultsTo: '20', help: '送入 ASR 的音频分片毫秒数')
    ..addOption('threads', defaultsTo: '1')
    ..addOption('decoding', defaultsTo: 'greedy_search')
    ..addOption('rule1', defaultsTo: '2.4')
    ..addOption('rule2', defaultsTo: '1.2')
    ..addOption('rule3', defaultsTo: '20')
    ..addOption('only', help: '只跑 id 包含该子串的片段')
    ..addFlag('compensation', help: '开启端到端延迟补偿（对照用）')
    ..addFlag('coverage', defaultsTo: true, help: '行级覆盖率放行（--no-coverage 对照）')
    ..addOption('limit')
    ..addFlag('dump', negatable: false, help: '打印滚动事件（配合 --only）')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(argv);
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final modelDir = args['model-dir'] as String?;
  if (modelDir == null) {
    stderr.writeln('缺少 --model-dir');
    exitCode = 2;
    return;
  }

  final evalDir = p.normalize(p.absolute(args['set'] as String));
  if (!File(p.join(evalDir, 'manifest.json')).existsSync()) {
    stderr.writeln('找不到 $evalDir/manifest.json');
    exitCode = 2;
    return;
  }

  final report = await runEvalSet(
    EvalOptions(
      modelDir: p.normalize(p.absolute(modelDir)),
      evalDir: evalDir,
      label: args['label'] as String,
      chunkMs: int.parse(args['chunk-ms'] as String),
      threads: int.parse(args['threads'] as String),
      decoding: args['decoding'] as String,
      rule1: double.parse(args['rule1'] as String),
      rule2: double.parse(args['rule2'] as String),
      rule3: double.parse(args['rule3'] as String),
      only: args['only'] as String?,
      limit: int.tryParse(args['limit'] as String? ?? ''),
      dumpEvents: args['dump'] as bool,
      latencyCompensation: args['compensation'] as bool,
      lineCoverage: args['coverage'] as bool,
    ),
    onSegment: stdout.writeln,
  );

  final outFile = File(p.normalize(p.absolute(args['out'] as String)));
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  final agg = report['aggregate'] as Map<String, dynamic>;
  stdout.writeln();
  stdout.writeln('== 汇总 ==');
  stdout.writeln('片段 ${agg['segments']}  CER ${agg['cer']}  '
      '命中率 ${agg['hitRate']}  跟随延迟P95 ${agg['followP95Ms']}ms  '
      '首字延迟P95 ${agg['firstCharP95Ms']}ms  '
      '误触发/分钟 ${agg['falseTriggerPerMin']}  RTF ${agg['rtf']}');
  stdout.writeln('报告：${outFile.path}');
}
