import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'asr_runner.dart';
import 'follow_sim.dart';
import 'metrics.dart';
import 'text_metrics.dart';
import 'wav.dart';

/// 评测运行参数。
class EvalOptions {
  const EvalOptions({
    required this.modelDir,
    required this.evalDir,
    this.label = 'host',
    this.chunkMs = 20,
    this.only,
    this.limit,
    this.threads = 1,
    this.decoding = 'greedy_search',
    this.rule1 = 2.4,
    this.rule2 = 1.2,
    this.rule3 = 20,
    this.dumpEvents = false,
    this.latencyCompensation = false,
    this.lineCoverage = true,
  });

  final String modelDir;
  final String evalDir;
  final String label;
  final int chunkMs;
  final String? only;
  final int? limit;
  final int threads;
  final String decoding;
  final double rule1;
  final double rule2;
  final double rule3;

  /// 打印每条滚动事件（诊断对齐/闸门用）。
  final bool dumpEvents;

  /// 是否开启端到端延迟补偿（补偿前/后对照用）。
  final bool latencyCompensation;

  /// 是否开启行级覆盖率放行（关闭即为旧的逐行闸门口径）。
  final bool lineCoverage;
}

/// 跑完整个评测集，返回可直接序列化为 JSON 的报告。
///
/// 同时通过 [onSegment] 回调输出过程日志（CLI 打印 / 真机 print）。
Future<Map<String, dynamic>> runEvalSet(
  EvalOptions options, {
  void Function(String log)? onSegment,
}) async {
  final manifestFile = File(p.join(options.evalDir, 'manifest.json'));
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  var segments = (manifest['segments'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((s) => s['status'] == 'ready')
      .toList();
  if (options.only != null) {
    segments = segments
        .where((s) => (s['id'] as String).contains(options.only!))
        .toList();
  }
  if (options.limit != null) {
    segments = segments.take(options.limit!).toList();
  }

  final config = AsrConfig(
    modelDir: p.normalize(p.absolute(options.modelDir)),
    numThreads: options.threads,
    decodingMethod: options.decoding,
    rule1MinTrailingSilence: options.rule1,
    rule2MinTrailingSilence: options.rule2,
    rule3MinUtteranceLength: options.rule3,
  );

  await StreamingAsrRunner.ensureBindings();
  final runner = StreamingAsrRunner(config);
  final results = <SegmentMetrics>[];
  final budgetSegments = <Map<String, Object?>>[];
  final allChunkDecode = <double>[];
  final allAlignUs = <double>[];
  final allAsrGaps = <double>[];
  var totalChunks = 0;
  var totalDecodeCalls = 0;
  var totalAudioMs = 0;
  var totalDecodeMs = 0.0;
  var dpRuns = 0;
  var dpCells = 0;
  var prescreenDpRuns = 0;
  var reanchorScans = 0;
  var reanchorDpRuns = 0;
  var dpMicros = 0.0;
  var maxSingleLeap = 0;
  var maxLeapPer10s = 0;
  var totalLeapLines = 0;

  for (final segment in segments) {
    final id = segment['id'] as String;
    final labelFile = File(p.join(options.evalDir, segment['label'] as String));
    final audioFile = File(p.join(options.evalDir, segment['audio'] as String));
    if (!labelFile.existsSync() || !audioFile.existsSync()) {
      onSegment?.call('跳过 $id：缺少标注或音频');
      continue;
    }

    final label = SegmentLabel.fromJson(
      jsonDecode(labelFile.readAsStringSync()) as Map<String, dynamic>,
    );
    final wav = parseWav(audioFile.readAsBytesSync());
    var samples = wav.mono();
    if (wav.sampleRate != 16000) {
      samples = resample(samples, wav.sampleRate, 16000);
    }

    final rssBefore = ProcessInfo.currentRss;
    final run =
        runner.run(samples, sampleRate: 16000, chunkMs: options.chunkMs);
    final rssAfter = ProcessInfo.currentRss;

    final sim = FollowSimulator(
      lines: label.lines.map((l) => l.text).toList(),
      latencyCompensation: options.latencyCompensation,
      lineCoverage: options.lineCoverage,
      chunkMs: options.chunkMs,
    );
    if (options.dumpEvents) sim.trace = onSegment;
    for (final e in run.events) {
      sim.onAsr(
        audioMs: e.audioMs,
        text: e.text,
        isFinal: e.isFinal,
        decodeMs: e.decodeMs,
      );
    }

    final reference = label.spokenLines.map((l) => l.text).join();
    final hypothesis = run.utterances.join();
    final cer = computeCer(hypothesis, reference);

    // 延迟分解：采集/解码分段、对齐调用、ASR 出字节奏、逐行等待。
    final m = sim.alignMetrics;
    allChunkDecode.addAll(run.chunkDecodeMs);
    allAlignUs.addAll(sim.alignUs);
    allAsrGaps.addAll(sim.asrGapsMs.map((e) => e.toDouble()));
    totalChunks += run.chunks;
    totalDecodeCalls += run.decodeCalls;
    totalAudioMs += run.audioMs;
    totalDecodeMs += run.decodeMs;
    dpRuns += m.dpRuns;
    dpCells += m.dpCells;
    prescreenDpRuns += m.prescreenDpRuns;
    reanchorScans += m.reanchorScans;
    reanchorDpRuns += m.reanchorDpRuns;
    dpMicros += m.dpMicros;
    final jumps = _jumpStats(sim.events);
    final singleLeap = jumps['maxSingleLeapLines'] as int;
    final leapPer10s = jumps['maxLeapLinesPer10s'] as int;
    if (singleLeap > maxSingleLeap) maxSingleLeap = singleLeap;
    if (leapPer10s > maxLeapPer10s) maxLeapPer10s = leapPer10s;
    totalLeapLines += jumps['totalLeapLines'] as int;
    budgetSegments.add({
      'id': id,
      'category': segment['category'],
      'audioMs': run.audioMs,
      'chunkMs': options.chunkMs,
      'chunks': run.chunks,
      'decodeCalls': run.decodeCalls,
      'decodeTotalMs': _r(run.decodeMs),
      'rtf': (run.decodeMs / (run.audioMs == 0 ? 1 : run.audioMs) * 10000)
              .round() /
          10000,
      'chunkDecodeMs': _stats(run.chunkDecodeMs),
      'asrEventGapMs': _stats(sim.asrGapsMs.map((e) => e.toDouble()).toList()),
      'alignCallUs': _stats(sim.alignUs),
      'alignCalls': sim.alignUs.length,
      'dp': m.toJson(),
      'jumps': jumps,
      'lines': _lineBreakdown(label, sim),
    });

    final metrics = computeMetrics(
      id: id,
      category: segment['category'] as String,
      label: label,
      asrEvents: run.events
          .map((e) => AsrEventLike(audioMs: e.audioMs, text: e.text))
          .toList(),
      scrollEvents: sim.events,
      rtf: run.rtf,
      decodeMs: run.decodeMs,
      loadMs: run.loadMs,
      utterances: run.utterances,
      hypothesis: hypothesis,
      cer: cer.cer,
      distance: cer.distance,
      refTokens: cer.refLength,
      reference: reference,
    );
    results.add(metrics);

    onSegment?.call(
      '--- $id (${metrics.category}) ---\n'
      'CER ${(metrics.cer * 100).toStringAsFixed(1)}%  '
      '首字延迟 均值 ${metrics.firstCharLatency.mean.toStringAsFixed(0)}ms / '
      'P95 ${metrics.firstCharLatency.p95.toStringAsFixed(0)}ms  '
      '跟随延迟 均值 ${metrics.followLatency.mean.toStringAsFixed(0)}ms  '
      '命中率 ${(metrics.hitRate * 100).toStringAsFixed(0)}%  '
      '误触发 ${metrics.falseTriggers}  RTF ${metrics.rtf.toStringAsFixed(3)}  '
      'RSS +${((rssAfter - rssBefore) / 1048576).toStringAsFixed(0)}MB\n'
      '识别: ${metrics.hypothesis}\n'
      '标注: ${metrics.reference}'
      '${options.dumpEvents ? '\n${sim.events.map((e) => '  ${e.audioMs}ms line=${e.line} char=${e.charOffset} conf=${e.confidence.toStringAsFixed(2)} ${e.reason}').join('\n')}' : ''}',
    );
  }

  final report = buildReport(
    results: results,
    config: {
      'asr': config.toJson(),
      'chunkMs': options.chunkMs,
      'modelDir': config.modelDir,
      'latencyCompensation': options.latencyCompensation,
      'lineCoverage': options.lineCoverage,
    },
    label: options.label,
    evalDir: options.evalDir,
  );
  report['latencyBudget'] = {
    'chunkMs': options.chunkMs,
    'chunks': totalChunks,
    'decodeCalls': totalDecodeCalls,
    'audioMs': totalAudioMs,
    'decodeTotalMs': _r(totalDecodeMs),
    'decodePerChunkMs': _stats(allChunkDecode),
    'asrEventGapMs': _stats(allAsrGaps),
    'alignCallUs': _stats(allAlignUs),
    'alignCalls': allAlignUs.length,
    'dp': {
      'dpRuns': dpRuns,
      'dpCells': dpCells,
      'prescreenDpRuns': prescreenDpRuns,
      'reanchorScans': reanchorScans,
      'reanchorDpRuns': reanchorDpRuns,
      'dpMicros': _r(dpMicros),
      'dpUsPerCall': dpRuns == 0 ? 0 : _r(dpMicros / dpRuns),
      'dpCellsPerCall': dpRuns == 0 ? 0 : _r(dpCells / dpRuns),
      'dpCallsPerAlign':
          allAlignUs.isEmpty ? 0 : _r(dpRuns / allAlignUs.length),
    },
    'segments': budgetSegments,
    'jumps': {
      'maxSingleLeapLines': maxSingleLeap,
      'maxLeapLinesPer10s': maxLeapPer10s,
      'totalLeapLines': totalLeapLines,
    },
  };
  return report;
}

/// 单个统计块（P50/P95/max/mean），单位由调用方决定。
Map<String, Object?> _stats(List<double> values) {
  final s = Stats(values: values);
  return {
    'count': s.count,
    'p50': _r(s.p50),
    'p95': _r(s.p95),
    'mean': _r(s.mean),
    'max': _r(s.max),
  };
}

/// 跳行统计：单次最大跳行数 + 任意 10 s 窗口内累计跳行数。
///
/// 红线：单次 ≤3 行、任意 10 s 累计 ≤3 行。逐行推进不计入跳行。
Map<String, Object?> _jumpStats(List<ScrollEvent> events) {
  var maxSingle = 0;
  var maxPer10s = 0;
  var total = 0;
  final jumps = <({int ms, int lines})>[];
  var prev = 0;
  for (final e in events) {
    final delta = e.line - prev;
    if (delta > 1) {
      jumps.add((ms: e.audioMs, lines: delta));
      total += delta;
      if (delta > maxSingle) maxSingle = delta;
    } else if (delta == 1) {
      jumps.add((ms: e.audioMs, lines: 1));
    }
    prev = e.line;
  }
  for (var i = 0; i < jumps.length; i++) {
    var sum = 0;
    for (var j = i; j < jumps.length; j++) {
      if (jumps[j].ms - jumps[i].ms > 10000) break;
      sum += jumps[j].lines > 1 ? jumps[j].lines : 0;
    }
    if (sum > maxPer10s) maxPer10s = sum;
  }
  return {
    'maxSingleLeapLines': maxSingle,
    'maxLeapLinesPer10s': maxPer10s,
    'totalLeapLines': total,
    'leapCount': jumps.where((j) => j.lines > 1).length,
  };
}

/// 逐行把「跟随延迟」拆成三段：对齐跨行 → 跟踪器接受 → 闸门/模式放行。
///
/// 每段的值为**相对该行开口时间**的毫秒数；`null` 表示该段没有出现
/// （例如整行没有命中、或行从未被滚到）。
List<Map<String, Object?>> _lineBreakdown(
  SegmentLabel label,
  FollowSimulator sim,
) {
  final out = <Map<String, Object?>>[];
  for (final line in label.spokenLines) {
    AlignTimelineEvent? alignCross;
    AlignTimelineEvent? trackerCross;
    ScrollEvent? scrollCross;
    for (final e in sim.matchedEvents) {
      if (alignCross == null && e.line >= line.index) alignCross = e;
      if (trackerCross == null && e.trackerLine >= line.index) {
        trackerCross = e;
      }
      if (alignCross != null && trackerCross != null) break;
    }
    for (final e in sim.events) {
      if (e.line >= line.index) {
        scrollCross = e;
        break;
      }
    }
    int? rel(int? ms) => ms == null ? null : ms - line.startMs;
    out.add({
      'line': line.index,
      'startMs': line.startMs,
      'alignCrossMs': rel(alignCross?.ms),
      'trackerCrossMs': rel(trackerCross?.ms),
      'scrollCrossMs': rel(scrollCross?.audioMs),
      'alignToTrackerMs': (alignCross == null || trackerCross == null)
          ? null
          : trackerCross.ms - alignCross.ms,
      'trackerToScrollMs': (trackerCross == null || scrollCross == null)
          ? null
          : scrollCross.audioMs - trackerCross.ms,
    });
  }
  return out;
}

/// 长跑：复用同一个 recognizer 循环全部可用片段，直到墙钟达到 [durationMs]。
///
/// 用于真机观察 RTF 漂移与内存增长（模型只加载一次）。
Future<Map<String, dynamic>> runLongRunSet(
  EvalOptions options, {
  required int durationMs,
  void Function(String log)? onSegment,
}) async {
  final manifestFile = File(p.join(options.evalDir, 'manifest.json'));
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final segments = (manifest['segments'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((s) => s['status'] == 'ready')
      .toList();

  final clips = <Float32List>[];
  for (final segment in segments) {
    final audioFile = File(p.join(options.evalDir, segment['audio'] as String));
    if (!audioFile.existsSync()) continue;
    final wav = parseWav(audioFile.readAsBytesSync());
    var samples = wav.mono();
    if (wav.sampleRate != 16000) {
      samples = resample(samples, wav.sampleRate, 16000);
    }
    clips.add(samples);
  }
  if (clips.isEmpty) {
    throw StateError('长跑没有可用音频，请检查 $options.evalDir');
  }

  final config = AsrConfig(
    modelDir: p.normalize(p.absolute(options.modelDir)),
    numThreads: options.threads,
    decodingMethod: options.decoding,
    rule1MinTrailingSilence: options.rule1,
    rule2MinTrailingSilence: options.rule2,
    rule3MinUtteranceLength: options.rule3,
  );

  await StreamingAsrRunner.ensureBindings();
  final runner = StreamingAsrRunner(config);
  onSegment?.call(
    '[longrun] 开始：${durationMs}ms / ${clips.length} 段循环 / '
    'model=${config.modelDir}',
  );
  final result = runner.runRepeated(
    clips,
    sampleRate: 16000,
    chunkMs: options.chunkMs,
    minWallMs: durationMs,
  );
  for (final round in result.rounds) {
    onSegment?.call(
      '[longrun] round ${round.round} wall=${round.wallMs}ms '
      'audio=${round.audioMs}ms rtf=${round.rtf.toStringAsFixed(3)} '
      'rss=${(round.rssBytes / 1048576).toStringAsFixed(0)}MiB',
    );
  }

  return {
    'version': 1,
    'generatedAt': DateTime.now().toIso8601String(),
    'environment': options.label,
    'config': config.toJson(),
    'loadMs': (result.loadMs * 10).round() / 10,
    'durationMs': durationMs,
    'rounds': result.rounds.map((e) => e.toJson()).toList(),
  };
}

/// 汇总所有片段指标。
Map<String, dynamic> buildReport({
  required List<SegmentMetrics> results,
  required Map<String, Object?> config,
  required String label,
  required String evalDir,
}) {
  var dist = 0;
  var refLen = 0;
  var hit = 0;
  var spoken = 0;
  var falseTriggers = 0;
  var silenceMinutes = 0.0;
  var decodeMs = 0.0;
  var audioMs = 0;
  final firstChar = <double>[];
  final follow = <double>[];

  for (final r in results) {
    dist += r.distance;
    refLen += r.refTokens;
    hit += r.hitLines;
    spoken += r.spokenLines;
    falseTriggers += r.falseTriggers;
    silenceMinutes += r.silenceMinutes;
    decodeMs += r.decodeMs;
    audioMs += r.durationMs;
    firstChar.addAll(r.firstCharLatency.values);
    follow.addAll(r.followLatency.values);
  }

  final firstStats = Stats(values: firstChar);
  final followStats = Stats(values: follow);
  final byCategory = <String, List<SegmentMetrics>>{};
  for (final r in results) {
    byCategory.putIfAbsent(r.category, () => []).add(r);
  }

  return {
    'version': 1,
    'generatedAt': DateTime.now().toIso8601String(),
    'environment': label,
    'evalDir': evalDir,
    'dart': Platform.version,
    'platform': Platform.operatingSystem,
    'config': config,
    'aggregate': {
      'segments': results.length,
      'cer': _pct(refLen == 0 ? 0 : dist / refLen),
      'distance': dist,
      'refTokens': refLen,
      'hitRate': _pct(spoken == 0 ? 0 : hit / spoken),
      'hitLines': hit,
      'spokenLines': spoken,
      'firstCharP50Ms': _r(firstStats.p50),
      'firstCharP95Ms': _r(firstStats.p95),
      'followP50Ms': _r(followStats.p50),
      'followP95Ms': _r(followStats.p95),
      'followMeanMs': _r(followStats.mean),
      'falseTriggers': falseTriggers,
      'falseTriggerPerMin':
          _r(silenceMinutes <= 0 ? 0 : falseTriggers / silenceMinutes),
      'rtf': (decodeMs / (audioMs == 0 ? 1 : audioMs) * 10000).round() / 10000,
    },
    'categories': {
      for (final entry in byCategory.entries)
        entry.key: {
          'segments': entry.value.length,
          'cer': _pct(_ratio([...entry.value.map((e) => e.distance)],
              [...entry.value.map((e) => e.refTokens)])),
          'hitRate': _pct(_ratio([...entry.value.map((e) => e.hitLines)],
              [...entry.value.map((e) => e.spokenLines)])),
          'followP95Ms': _r(Stats(values: [
            for (final e in entry.value) ...e.followLatency.values,
          ]).p95),
        },
    },
    'segments': results.map((r) => r.toJson()).toList(),
  };
}

double _ratio(List<int> num, List<int> den) {
  final n = num.fold<int>(0, (a, b) => a + b);
  final d = den.fold<int>(0, (a, b) => a + b);
  return d == 0 ? 0 : n / d;
}

double _r(double v) => (v * 10).roundToDouble() / 10;

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
