import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'lib/wav.dart';

/// 用 macOS `say` 生成 P0 评测音频与逐行时间标注。
///
/// 用途：在没有真人录音前先建立**可重复**的基线；TTS 音频不代表真人分布，
/// 结果只用于版本间相对比较，不能当作绝对准确率。
///
/// 用法：
/// ```
/// dart run gen_tts_set.dart --set ../../eval
/// ```
Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('set', defaultsTo: '../../eval')
    ..addOption('voice', help: '覆盖脚本里的音色')
    ..addFlag('force', negatable: false, help: '已存在的音频也重新生成');
  final args = parser.parse(argv);

  if (!Platform.isMacOS) {
    stderr.writeln('gen_tts_set.dart 依赖 macOS 的 say 命令；其他平台请直接放真人录音。');
    exitCode = 2;
    return;
  }

  final evalDir = p.normalize(p.absolute(args['set'] as String));
  final scriptDir = Directory(p.join(evalDir, 'scripts', 'p0'));
  final audioDir = Directory(p.join(evalDir, 'audio'))
    ..createSync(recursive: true);
  final labelDir = Directory(p.join(evalDir, 'labels'))
    ..createSync(recursive: true);

  final files = scriptDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final entries = <Map<String, Object?>>[];
  for (final file in files) {
    final spec = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = spec['id'] as String;
    final category = spec['category'] as String;
    final voice =
        (args['voice'] as String?) ?? spec['voice'] as String? ?? 'Tingting';
    final audioFile = File(p.join(audioDir.path, '$id.wav'));
    final labelFile = File(p.join(labelDir.path, '$id.json'));

    if (!audioFile.existsSync() ||
        !labelFile.existsSync() ||
        (args['force'] as bool)) {
      if (spec['silenceOnlyMs'] != null) {
        await _writeSilence(
          id: id,
          durationMs: spec['silenceOnlyMs'] as int,
          audioFile: audioFile,
          labelFile: labelFile,
        );
      } else {
        await _synthesize(
          id: id,
          spec: spec,
          voice: voice,
          audioFile: audioFile,
          labelFile: labelFile,
        );
      }
      stdout.writeln('生成 $id');
    }

    final label =
        jsonDecode(labelFile.readAsStringSync()) as Map<String, dynamic>;
    entries.add({
      'id': id,
      'category': category,
      'status': 'ready',
      'script': p.relative(file.path, from: evalDir),
      'label': p.relative(labelFile.path, from: evalDir),
      'audio': p.relative(audioFile.path, from: evalDir),
      'durationSec': ((label['durationMs'] as int) / 1000).toStringAsFixed(1),
      'source': 'synthetic-tts',
      'voice': spec['silenceOnlyMs'] != null ? null : voice,
      'license': 'self-generated (macOS say), no third-party audio',
      'note': 'synthetic-tts：只用于版本间相对比较，不代表真人分布',
    });
  }

  final manifest = {
    'version': 1,
    'updated': DateTime.now().toIso8601String().split('T').first,
    'generatedBy': 'tool/eval/gen_tts_set.dart',
    'audioFormat': {
      'sampleRate': 16000,
      'channels': 1,
      'encoding': 'pcm_s16le'
    },
    'design': {
      'reference': 'docs/testing/TESTING.md §5.1（60 段）',
      'p0': 'P0 先跑 10 段合成语音，覆盖类别；真人录音按同一目录结构补齐后把 status 改为 ready',
      'quotas': {
        '普通话男声': 12,
        '普通话女声': 12,
        '方言口音': 10,
        '中英混读': 8,
        '含口误/重复/甩词': 8,
        '含跳读/插话': 6,
        '噪声/回声': 4,
      },
      'segmentLengthSec': '60–120',
      'licenseRule': '每段必须登记来源与授权；第三方音频不得入库，只记录路径与授权书编号',
    },
    'segments': entries,
  };
  File(p.join(evalDir, 'manifest.json')).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  stdout.writeln('写入 manifest.json：${entries.length} 段');
}

Future<void> _synthesize({
  required String id,
  required Map<String, dynamic> spec,
  required String voice,
  required File audioFile,
  required File labelFile,
}) async {
  final lines = (spec['lines'] as List<dynamic>).cast<Map<String, dynamic>>();
  final leading = spec['leadingSilenceMs'] as int? ?? 500;
  final trailing = spec['trailingSilenceMs'] as int? ?? 800;
  const sampleRate = 16000;

  final samples = <double>[];
  final labelLines = <Map<String, Object?>>[];
  var cursorMs = leading;
  samples.addAll(List<double>.filled(leading * sampleRate ~/ 1000, 0));

  final tmp = Directory.systemTemp.createTempSync('asr_eval_');
  try {
    var index = 0;
    for (final line in lines) {
      final text = line['text'] as String;
      final spoken = line['spoken'] as bool? ?? true;
      if (!spoken) {
        labelLines.add({
          'index': index++,
          'text': text,
          'startMs': cursorMs,
          'endMs': cursorMs,
          'spoken': false,
        });
        continue;
      }

      final textFile = File(p.join(tmp.path, 'line_$index.txt'))
        ..writeAsStringSync(text);
      final outFile = p.join(tmp.path, 'line_$index.wav');
      final result = await Process.run('say', [
        '-v',
        voice,
        '-o',
        outFile,
        '--data-format=LEI16@16000',
        '-f',
        textFile.path,
      ]);
      if (result.exitCode != 0) {
        throw StateError('say 失败（$id / $index）：${result.stderr}');
      }
      final wav = parseWav(File(outFile).readAsBytesSync());
      if (wav.sampleRate != sampleRate) {
        throw StateError('say 输出采样率异常：${wav.sampleRate}');
      }
      final mono = wav.mono();
      samples.addAll(mono);
      final durationMs = mono.length * 1000 ~/ sampleRate;
      labelLines.add({
        'index': index,
        'text': text,
        'startMs': cursorMs,
        'endMs': cursorMs + durationMs,
        'spoken': true,
      });
      cursorMs += durationMs;
      final pause = line['pauseAfterMs'] as int? ?? 500;
      samples.addAll(List<double>.filled(pause * sampleRate ~/ 1000, 0));
      cursorMs += pause;
      index++;
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }

  samples.addAll(List<double>.filled(trailing * sampleRate ~/ 1000, 0));
  cursorMs += trailing;

  audioFile.writeAsBytesSync(encodeWav(Float32List.fromList(samples)));
  labelFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'id': id,
      'lines': labelLines,
      'durationMs': cursorMs,
    }),
  );
}

Future<void> _writeSilence({
  required String id,
  required int durationMs,
  required File audioFile,
  required File labelFile,
}) async {
  const sampleRate = 16000;
  audioFile.writeAsBytesSync(
    encodeWav(Float32List(durationMs * sampleRate ~/ 1000)),
  );
  labelFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'id': id,
      'lines': <Object>[],
      'durationMs': durationMs,
    }),
  );
}
