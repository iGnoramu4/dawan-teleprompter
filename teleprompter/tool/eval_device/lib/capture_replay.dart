import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:asr_kit/asr_kit.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

/// 真机麦克风「录一段 → 回放」取证。
///
/// 同一条 WAV 走两条路：
/// 1. 实时节拍（[WavReplaySource]）喂生产解码引擎，记录积压/心跳/出字时间；
/// 2. 离线全速解码（多种分片长度），拿到同一段音频的理想文本与 RTF。
///
/// 只有实时节拍下积压单调增长、且出字时间持续后移，才说明「解码吞吐不足」；
/// 若积压为 0 而更新中断，则问题在采集或引擎存活，不在算力分配。

/// 从模型目录识别实际文件（encoder 固定 int8，decoder/joiner 可能是 int8 或 fp32）。
AsrModelSpec detectSpec(String modelDir) {
  final names = Directory(modelDir)
      .listSync()
      .whereType<File>()
      .map((file) => p.basename(file.path))
      .toSet();
  String pick(String base) {
    final int8 = '$base.int8.onnx';
    return names.contains(int8) ? int8 : '$base.onnx';
  }

  return AsrModelSpec(
    id: 'eval-detected',
    assetDir: modelDir,
    encoderFile: pick('encoder-epoch-99-avg-1'),
    decoderFile: pick('decoder-epoch-99-avg-1'),
    joinerFile: pick('joiner-epoch-99-avg-1'),
    tokensFile: 'tokens.txt',
  );
}

/// 用生产采集配置录音，返回 16 kHz / 单声道 / PCM16 WAV。
///
/// 采集不走任何额外处理，分片大小与生产完全一致（`bufferMs = 0` 透传插件分片），
/// 这样「分片 → 解码」的固定开销与线上同口径。
Future<File> recordMic({
  required Directory outDir,
  required Duration duration,
  void Function(String)? onLog,
}) async {
  await outDir.create(recursive: true);
  final capture = AudioCapture();
  final stream = await capture.start();
  final pcm = BytesBuilder(copy: false);
  final levels = <Map<String, Object?>>[];

  var curSamples = 0;
  var curSumSq = 0.0;
  var curPeak = 0.0;
  var curChunks = 0;
  var second = 0;

  void flushLevel() {
    if (curSamples == 0) return;
    levels.add({
      'sec': second,
      'rms': _round(math.sqrt(curSumSq / curSamples)),
      'peak': _round(curPeak),
      'chunks': curChunks,
      'chunkMs':
          curChunks == 0 ? 0 : (curSamples * 1000 / 16000 / curChunks).round(),
    });
    second++;
    curSamples = 0;
    curSumSq = 0;
    curPeak = 0;
    curChunks = 0;
  }

  final done = Completer<void>();
  StreamSubscription<Float32List>? sub;
  Timer? timer;

  Future<void> finish() async {
    if (done.isCompleted) return;
    timer?.cancel();
    await sub?.cancel();
    await capture.stop();
    await capture.dispose();
    flushLevel();
    done.complete();
  }

  final startedAt = DateTime.now();
  sub = stream.listen(
    (chunk) {
      pcm.add(_float32ToPcm16(chunk));
      curChunks++;
      curSamples += chunk.length;
      for (final value in chunk) {
        final amp = value.abs();
        curSumSq += value * value;
        if (amp > curPeak) curPeak = amp;
      }
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed.inSeconds > second) flushLevel();
    },
    onError: (Object error) {
      onLog?.call('录音失败: $error');
      unawaited(finish());
    },
    onDone: () => unawaited(finish()),
  );
  timer = Timer(duration, () => unawaited(finish()));
  await done.future;

  final bytes = _wrapWav(pcm.takeBytes(), sampleRate: 16000, channels: 1);
  final stamp =
      DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
  final file = File(p.join(outDir.path, 'mic-$stamp.wav'));
  await file.writeAsBytes(bytes, flush: true);
  onLog?.call('已录音 ${duration.inSeconds}s → ${file.path}');

  File(p.join(outDir.path, 'mic-$stamp.levels.json')).writeAsStringSync(
    _json({'sampleRate': 16000, 'seconds': levels.length, 'levels': levels}),
  );
  return file;
}

/// 实时节拍回放：按 [chunkMs] 匀速喂生产引擎，并记录积压与出字时间。
Future<Map<String, Object?>> replayRealtime({
  required File wavFile,
  required String modelDir,
  required AsrModelSpec spec,
  int chunkMs = 32,
  void Function(String)? onLog,
}) async {
  final wav = PcmWav.parse(await wavFile.readAsBytes());
  final samples = wav.sampleRate == 16000
      ? wav.samples
      : _resample(wav.samples, wav.sampleRate, 16000);
  final audioMs = samples.length * 1000 / 16000;

  final engine = SherpaAsrEngine();
  await engine.start(InstalledAsrModel(spec: spec, dir: modelDir));

  final updates = <Map<String, Object?>>[];
  final ticks = <Map<String, Object?>>[];
  final errors = <String>[];
  final clock = Stopwatch()..start();
  int nowMs() => clock.elapsedMilliseconds;

  final updateSub = engine.updates.listen(
    (update) {
      updates.add({
        'wallMs': nowMs(),
        'fedMs': engine.fedAudioMs.round(),
        'text': update.text,
        'isFinal': update.isFinal,
        'decodeMs': _round(update.decodeMs),
      });
    },
    onError: (Object error) => errors.add('$error'),
  );
  final tickSub = engine.ticks.listen((tick) {
    ticks.add({
      'wallMs': nowMs(),
      'backlogMs': engine.backlogMs.round(),
      'fedMs': engine.fedAudioMs.round(),
      'processedMs': tick.processedAudioMs.round(),
      'decodeTotalMs': tick.decodeTotalMs.round(),
      'rtf': _round(
        tick.processedAudioMs <= 0
            ? 0
            : tick.decodeTotalMs / tick.processedAudioMs,
      ),
      'decodeMs': _round(tick.decodeMs),
    });
  });

  final playClock = Stopwatch()..start();
  await for (final chunk in WavReplaySource(
    PcmWav(sampleRate: 16000, channels: 1, samples: samples),
    chunkMs: chunkMs,
  ).play()) {
    engine.accept(chunk);
  }
  final playedMs = playClock.elapsedMilliseconds;
  await engine.flush();
  final totalMs = nowMs();

  await updateSub.cancel();
  await tickSub.cancel();
  await engine.dispose();

  onLog?.call(
    '实时回放完成：音频 ${audioMs.round()}ms / 墙钟 ${totalMs}ms / '
    'update ${updates.length} / tick ${ticks.length}',
  );

  return {
    'chunkMs': chunkMs,
    'audioMs': audioMs.round(),
    'wallMs': totalMs,
    'playedMs': playedMs,
    'died': engine.engineDied,
    'errors': errors,
    'updates': updates,
    'ticks': ticks,
    'summary': _realtimeSummary(updates, ticks, audioMs),
  };
}

/// 离线全速解码：同一段音频在不同分片长度下的理想文本与 RTF。
Future<Map<String, Object?>> offlineDecode({
  required File wavFile,
  required AsrModelSpec spec,
  List<int> chunkSizes = const [20, 40, 100],
}) async {
  final wav = PcmWav.parse(await wavFile.readAsBytes());
  final samples = wav.sampleRate == 16000
      ? wav.samples
      : _resample(wav.samples, wav.sampleRate, 16000);
  so.initBindings();

  final results = <String, Object?>{};
  for (final chunkMs in chunkSizes) {
    final recognizer = so.OnlineRecognizer(
      so.OnlineRecognizerConfig(
        model: so.OnlineModelConfig(
          transducer: so.OnlineTransducerModelConfig(
            encoder: p.join(spec.assetDir, spec.encoderFile),
            decoder: p.join(spec.assetDir, spec.decoderFile),
            joiner: p.join(spec.assetDir, spec.joinerFile),
          ),
          tokens: p.join(spec.assetDir, spec.tokensFile),
          numThreads: 1,
          modelType: spec.modelType,
        ),
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
      ),
    );
    final stream = recognizer.createStream();
    final chunk = (16000 * chunkMs / 1000).round();
    final texts = <String>[];
    var lastText = '';
    var decodeMs = 0.0;
    var fed = 0;
    while (fed < samples.length) {
      final end = math.min(fed + chunk, samples.length);
      final watch = Stopwatch()..start();
      stream.acceptWaveform(
        samples: Float32List.sublistView(samples, fed, end),
        sampleRate: 16000,
      );
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      decodeMs += watch.elapsedMicroseconds / 1000;
      fed = end;
      final text = recognizer.getResult(stream).text;
      final endpoint = recognizer.isEndpoint(stream);
      if (text.isNotEmpty && text != lastText) {
        texts.add(text);
        lastText = text;
      }
      if (endpoint) {
        if (text.isNotEmpty) lastText = '';
        recognizer.reset(stream);
      }
    }
    stream.inputFinished();
    final tailClock = Stopwatch()..start();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    decodeMs += tailClock.elapsedMicroseconds / 1000;
    final tail = recognizer.getResult(stream).text;
    if (tail.isNotEmpty && tail != lastText) texts.add(tail);
    stream.free();
    recognizer.free();

    results['$chunkMs'] = {
      'chunkMs': chunkMs,
      'rtf': _round(decodeMs / (samples.length * 1000 / 16000)),
      'decodeMs': decodeMs.round(),
      'events': texts.length,
      'texts': texts,
    };
  }
  return results;
}

Map<String, Object?> _realtimeSummary(
  List<Map<String, Object?>> updates,
  List<Map<String, Object?>> ticks,
  double audioMs,
) {
  var maxBacklog = 0;
  var lastBacklog = 0;
  for (final tick in ticks) {
    final backlog = tick['backlogMs'] as int? ?? 0;
    if (backlog > maxBacklog) maxBacklog = backlog;
    lastBacklog = backlog;
  }
  var maxGapMs = 0;
  var prev = -1;
  for (final update in updates) {
    final wall = update['wallMs'] as int? ?? 0;
    if (prev >= 0 && wall - prev > maxGapMs) maxGapMs = wall - prev;
    prev = wall;
  }
  final lastFed = updates.isEmpty ? 0 : updates.last['fedMs'] as int? ?? 0;
  return {
    'maxBacklogMs': maxBacklog,
    'lastBacklogMs': lastBacklog,
    'maxUpdateGapMs': maxGapMs,
    'updateCount': updates.length,
    'audioMs': audioMs.round(),
    'lastFedMs': lastFed,
  };
}

Uint8List _float32ToPcm16(Float32List samples) {
  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    view.setInt16(i * 2, value, Endian.little);
  }
  return bytes;
}

Uint8List _wrapWav(Uint8List pcm,
    {required int sampleRate, required int channels}) {
  const bits = 16;
  final byteRate = sampleRate * channels * bits ~/ 8;
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * bits ~/ 8, Endian.little);
  header.setUint16(34, bits, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}

Float32List _resample(Float32List input, int from, int to) {
  final out = Float32List((input.length * to / from).round());
  for (var i = 0; i < out.length; i++) {
    final pos = i * from / to;
    final index = pos.floor().clamp(0, input.length - 1);
    out[i] = input[index];
  }
  return out;
}

double _round(double value) => (value * 1000).roundToDouble() / 1000;

String _json(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
