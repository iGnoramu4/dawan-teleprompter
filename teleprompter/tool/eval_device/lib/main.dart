import 'dart:convert';
import 'dart:io';

import 'package:asr_eval/run_set.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'capture_replay.dart';

/// 真机评测入口。
///
/// 音频/模型不随包，构建时通过 --dart-define 指定设备上的路径，例如：
/// ```
/// flutter run -d <id> --profile \
///   --dart-define=EVAL_DIR=/sdcard/Android/data/com.dawan.teleprompter.eval_device/files/eval \
///   --dart-define=MODEL_DIR=/sdcard/Android/data/com.dawan.teleprompter.eval_device/files/models/zipformer-zh-14M-int8
/// ```
///
/// 三种模式：
/// - `MODE=eval`（默认）：跑 10 段 TTS 回归集，守红线；
/// - `MODE=record`：用设备麦克风录 [RECORD_SECONDS] 秒人声，再回放取证；
/// - `MODE=replay`：直接回放已存在的 WAV（[AUDIO] 绝对路径或相对 EVAL_DIR）。
///
/// 回放模式把同一条音频同时喂给「实时节拍的生产引擎」与「离线全速解码」，
/// 输出 `record-report-<label>.json`：积压时间线、出字时间线、两种文本对照。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EvalApp());
}

class EvalApp extends StatefulWidget {
  const EvalApp({super.key});

  @override
  State<EvalApp> createState() => _EvalAppState();
}

class _EvalAppState extends State<EvalApp> {
  static const _evalDir = String.fromEnvironment('EVAL_DIR');
  static const _modelDir = String.fromEnvironment('MODEL_DIR');
  static const _label = String.fromEnvironment(
    'RUN_LABEL',
    defaultValue: 'android-device',
  );

  /// eval：跑评测集；record：先录音再回放；replay：只回放已有 WAV。
  static const _mode = String.fromEnvironment('MODE', defaultValue: 'eval');

  /// 评测集离线解码分片（毫秒）。
  static const _chunkMs = int.fromEnvironment('CHUNK_MS', defaultValue: 20);

  /// 实时回放分片（毫秒）：32 = 与产品内回放一致，40 = 线上最小分片档。
  static const _replayChunkMs =
      int.fromEnvironment('REPLAY_CHUNK_MS', defaultValue: 32);

  /// 录音时长（秒）。
  static const _recordSeconds = int.fromEnvironment('RECORD_SECONDS');

  /// 回放文件：绝对路径，或相对 EVAL_DIR 的路径。
  static const _audio = String.fromEnvironment('AUDIO');

  /// 长跑时长（毫秒）；0 = 只跑一次评测集。
  static const _longRunMs = int.fromEnvironment('LONG_RUN_MS');

  /// 是否开启端到端延迟补偿（对照用）。
  static const _compensation = bool.fromEnvironment('LATENCY_COMPENSATION');

  String _status = '准备中…';
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      if (_evalDir.isEmpty || _modelDir.isEmpty) {
        throw StateError('未设置 EVAL_DIR / MODEL_DIR');
      }
      switch (_mode) {
        case 'record':
          await _runRecord();
        case 'replay':
          await _runReplay();
        case 'offline':
          await _runOffline();
        default:
          await _runEval();
      }
    } catch (error, stack) {
      debugPrint('[eval] FAILED $error\n$stack');
      if (mounted) setState(() => _status = '失败：$error');
    }
  }

  Future<void> _runEval() async {
    final report = await runEvalSet(
      EvalOptions(
        modelDir: _modelDir,
        evalDir: _evalDir,
        label: _label,
        chunkMs: _chunkMs,
        latencyCompensation: _compensation,
      ),
      onSegment: (log) => debugPrint('[eval] $log'),
    );
    final out = File(p.join(_evalDir, 'device-report-$_label.json'));
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    final agg = report['aggregate'] as Map<String, dynamic>;
    debugPrint('[eval] DONE ${jsonEncode(agg)}');
    if (mounted) {
      setState(() {
        _report = report;
        _status = '完成：${out.path}';
      });
    }

    if (_longRunMs > 0) {
      if (mounted) setState(() => _status = '长跑中：$_longRunMs ms');
      final longRun = await runLongRunSet(
        EvalOptions(modelDir: _modelDir, evalDir: _evalDir, label: _label),
        durationMs: _longRunMs,
        onSegment: (log) => debugPrint('[eval] $log'),
      );
      final longOut = File(p.join(_evalDir, 'longrun-report-$_label.json'));
      longOut.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(longRun),
      );
      debugPrint('[eval] LONGRUN_DONE ${jsonEncode(longRun['rounds'])}');
      if (mounted) setState(() => _status = '长跑完成：${longOut.path}');
    }
  }

  Future<void> _runRecord() async {
    final seconds = _recordSeconds <= 0 ? 60 : _recordSeconds;
    if (mounted) {
      setState(() => _status = '录音中：$seconds 秒（请按台本连续朗读）');
    }
    final file = await recordMic(
      outDir: Directory(p.join(_evalDir, 'recordings')),
      duration: Duration(seconds: seconds),
      onLog: (log) => debugPrint('[record] $log'),
    );
    if (mounted) setState(() => _status = '录音完成，开始回放：${file.path}');
    await _analyse(file, 'record');
  }

  Future<void> _runReplay() async {
    if (_audio.isEmpty) throw StateError('MODE=replay 需要 AUDIO');
    final file = File(
      _audio.startsWith('/') ? _audio : p.join(_evalDir, _audio),
    );
    if (!file.existsSync()) throw StateError('找不到音频：${file.path}');
    await _analyse(file, 'replay');
  }

  /// 只做离线全速解码：核实同一段音频在不同分片长度下的 RTF。
  Future<void> _runOffline() async {
    if (_audio.isEmpty) throw StateError('MODE=offline 需要 AUDIO');
    final file = File(
      _audio.startsWith('/') ? _audio : p.join(_evalDir, _audio),
    );
    if (!file.existsSync()) throw StateError('找不到音频：${file.path}');
    if (mounted) setState(() => _status = '离线解码中…');
    final spec = detectSpec(_modelDir);
    final offline = await offlineDecode(wavFile: file, spec: spec);
    final report = {
      'version': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'environment': _label,
      'audio': file.path,
      'modelDir': _modelDir,
      'model': {
        'encoder': spec.encoderFile,
        'decoder': spec.decoderFile,
        'joiner': spec.joinerFile,
      },
      'offline': offline,
    };
    final out = File(p.join(_evalDir, 'offline-report-$_label.json'));
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    debugPrint('[eval] OFFLINE_DONE ${jsonEncode({
          for (final entry in offline.entries)
            entry.key: (entry.value as Map)['rtf'],
        })}');
    if (mounted) {
      setState(() {
        _report = report;
        _status = '完成：${out.path}';
      });
    }
  }

  /// 同一条音频：实时节拍回放 + 离线全速解码，结果写 JSON。
  Future<void> _analyse(File file, String prefix) async {
    final spec = detectSpec(_modelDir);
    if (mounted) setState(() => _status = '实时回放中（${_replayChunkMs}ms 分片）…');
    final realtime = await replayRealtime(
      wavFile: file,
      modelDir: _modelDir,
      spec: spec,
      chunkMs: _replayChunkMs,
      onLog: (log) => debugPrint('[replay] $log'),
    );

    if (mounted) setState(() => _status = '离线解码中…');
    final offline = await offlineDecode(
      wavFile: file,
      spec: spec,
      chunkSizes: const [20, 40, 100],
    );

    final report = {
      'version': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'environment': _label,
      'audio': file.path,
      'modelDir': _modelDir,
      'model': {
        'encoder': spec.encoderFile,
        'decoder': spec.decoderFile,
        'joiner': spec.joinerFile,
      },
      'realtime': realtime,
      'offline': offline,
    };
    final out = File(p.join(_evalDir, '$prefix-report-$_label.json'));
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    debugPrint('[eval] RECORD_DONE ${jsonEncode(realtime['summary'])}');
    if (mounted) {
      setState(() {
        _report = report;
        _status = '完成：${out.path}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final agg = _report?['aggregate'] as Map<String, dynamic>?;
    final summary = _report?['realtime'] as Map<String, dynamic>?;
    final buffer = StringBuffer(_status);
    if (agg != null) {
      buffer.write('\n\n${const JsonEncoder.withIndent('  ').convert(agg)}');
    }
    if (summary != null) {
      buffer.write(
        '\n\n${const JsonEncoder.withIndent('  ').convert(summary['summary'])}',
      );
    }
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('ASR Eval Harness')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(buffer.toString(), style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
