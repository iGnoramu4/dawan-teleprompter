import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

/// 与 `asr_kit` 当前实现对齐的解码配置；所有字段都可从命令行覆盖，便于 A/B。
class AsrConfig {
  const AsrConfig({
    required this.modelDir,
    this.numThreads = 1,
    this.decodingMethod = 'greedy_search',
    this.enableEndpoint = true,
    this.rule1MinTrailingSilence = 2.4,
    this.rule2MinTrailingSilence = 1.2,
    this.rule3MinUtteranceLength = 20.0,
    this.modelType = '',
    this.hotwordsFile = '',
    this.hotwordsScore = 1.5,
    this.maxActivePaths = 4,
    this.blankPenalty = 0.0,
  });

  final String modelDir;
  final int numThreads;
  final String decodingMethod;
  final bool enableEndpoint;
  final double rule1MinTrailingSilence;
  final double rule2MinTrailingSilence;
  final double rule3MinUtteranceLength;
  final String modelType;
  final String hotwordsFile;
  final double hotwordsScore;
  final int maxActivePaths;
  final double blankPenalty;

  Map<String, Object?> toJson() => {
        'modelDir': modelDir,
        'numThreads': numThreads,
        'decodingMethod': decodingMethod,
        'enableEndpoint': enableEndpoint,
        'rule1MinTrailingSilence': rule1MinTrailingSilence,
        'rule2MinTrailingSilence': rule2MinTrailingSilence,
        'rule3MinUtteranceLength': rule3MinUtteranceLength,
        'modelType': modelType,
        'hotwordsFile': hotwordsFile,
        'hotwordsScore': hotwordsScore,
        'maxActivePaths': maxActivePaths,
        'blankPenalty': blankPenalty,
      };
}

/// 一次识别输出，时间戳是「已送入解码器的音频末尾」。
class AsrEvent {
  const AsrEvent({
    required this.audioMs,
    required this.text,
    required this.isFinal,
    required this.decodeMs,
  });

  final int audioMs;
  final String text;
  final bool isFinal;
  final double decodeMs;

  Map<String, Object?> toJson() => {
        'audioMs': audioMs,
        'text': text,
        'isFinal': isFinal,
        'decodeMs': decodeMs,
      };
}

/// 一次完整回放的结果。
class AsrRunResult {
  const AsrRunResult({
    required this.events,
    required this.audioMs,
    required this.decodeMs,
    required this.loadMs,
    required this.utterances,
    this.chunkDecodeMs = const <double>[],
    this.decodeCalls = 0,
    this.chunks = 0,
  });

  final List<AsrEvent> events;
  final int audioMs;
  final double decodeMs;
  final double loadMs;

  /// 按端点切分的最终文本。
  final List<String> utterances;

  /// 每个送入分片的解码耗时（ms），含未出字的静音分片。
  final List<double> chunkDecodeMs;

  /// `recognizer.decode` 实际调用次数（> chunks 说明有积压追赶）。
  final int decodeCalls;

  /// 送入分片数。
  final int chunks;

  double get rtf => audioMs == 0 ? 0 : decodeMs / audioMs;
}

/// 长跑一轮（循环整个评测集）的采样。
class LongRunRound {
  const LongRunRound({
    required this.round,
    required this.wallMs,
    required this.audioMs,
    required this.decodeMs,
    required this.rssBytes,
  });

  final int round;
  final int wallMs;
  final int audioMs;
  final double decodeMs;
  final int rssBytes;

  double get rtf => audioMs == 0 ? 0 : decodeMs / audioMs;

  Map<String, Object?> toJson() => {
        'round': round,
        'wallMs': wallMs,
        'audioMs': audioMs,
        'decodeMs': (decodeMs * 10).round() / 10,
        'rtf': (rtf * 10000).round() / 10000,
        'rssMiB': (rssBytes / 1048576 * 10).round() / 10,
      };
}

/// 长跑结果：首轮前加载耗时 + 每轮 RTF/RSS。
class LongRunResult {
  const LongRunResult({required this.loadMs, required this.rounds});

  final double loadMs;
  final List<LongRunRound> rounds;
}

/// 流式 ASR 回放器：按固定分片喂 WAV，记录每个出字的音频时间。
class StreamingAsrRunner {
  StreamingAsrRunner(this.config);

  final AsrConfig config;
  static bool _bindingsReady = false;

  static Future<void> ensureBindings() async {
    if (_bindingsReady) return;
    try {
      so.initBindings();
    } catch (_) {
      if (!Platform.isMacOS) rethrow;
      // 纯 Dart CLI 里进程未加载 dylib，按包路径手动加载。
      final resolved = await Isolate.resolvePackageUri(
        Uri.parse('package:sherpa_onnx_macos/pubspec.yaml'),
      );
      if (resolved == null) {
        throw StateError('找不到 sherpa_onnx_macos 包，无法加载 macOS dylib');
      }
      final root = File.fromUri(resolved).parent.path;
      so.initBindings('$root/macos');
    }
    _bindingsReady = true;
  }

  so.OnlineRecognizer _createRecognizer() {
    return so.OnlineRecognizer(
      so.OnlineRecognizerConfig(
        model: so.OnlineModelConfig(
          transducer: so.OnlineTransducerModelConfig(
            encoder: '${config.modelDir}/encoder-epoch-99-avg-1.int8.onnx',
            decoder: '${config.modelDir}/decoder-epoch-99-avg-1.int8.onnx',
            joiner: '${config.modelDir}/joiner-epoch-99-avg-1.int8.onnx',
          ),
          tokens: '${config.modelDir}/tokens.txt',
          numThreads: config.numThreads,
          modelType: config.modelType,
          debug: false,
        ),
        decodingMethod: config.decodingMethod,
        maxActivePaths: config.maxActivePaths,
        enableEndpoint: config.enableEndpoint,
        rule1MinTrailingSilence: config.rule1MinTrailingSilence,
        rule2MinTrailingSilence: config.rule2MinTrailingSilence,
        rule3MinUtteranceLength: config.rule3MinUtteranceLength,
        hotwordsFile: config.hotwordsFile,
        hotwordsScore: config.hotwordsScore,
        blankPenalty: config.blankPenalty,
      ),
    );
  }

  AsrRunResult run(
    Float32List samples, {
    required int sampleRate,
    int chunkMs = 20,
  }) {
    final sw = Stopwatch()..start();
    final recognizer = _createRecognizer();
    final loadMs = sw.elapsedMicroseconds / 1000.0;
    try {
      return _runWith(
        recognizer,
        samples,
        sampleRate: sampleRate,
        chunkMs: chunkMs,
        loadMs: loadMs,
      );
    } finally {
      recognizer.free();
    }
  }

  /// 复用同一个 recognizer 循环 [clips]，直到墙钟达到 [minWallMs]。
  ///
  /// 用于观察长时间解码的 RTF 漂移（不重复计模型加载）。
  LongRunResult runRepeated(
    List<Float32List> clips, {
    required int sampleRate,
    int chunkMs = 20,
    required int minWallMs,
  }) {
    final sw = Stopwatch()..start();
    final recognizer = _createRecognizer();
    final loadMs = sw.elapsedMicroseconds / 1000.0;
    final clock = Stopwatch()..start();
    final rounds = <LongRunRound>[];
    var round = 0;
    try {
      while (clock.elapsedMilliseconds < minWallMs) {
        var decodeMs = 0.0;
        var audioMs = 0;
        for (final clip in clips) {
          final result = _runWith(
            recognizer,
            clip,
            sampleRate: sampleRate,
            chunkMs: chunkMs,
            loadMs: loadMs,
          );
          decodeMs += result.decodeMs;
          audioMs += result.audioMs;
          if (clock.elapsedMilliseconds >= minWallMs) break;
        }
        rounds.add(LongRunRound(
          round: round++,
          wallMs: clock.elapsedMilliseconds,
          audioMs: audioMs,
          decodeMs: decodeMs,
          rssBytes: ProcessInfo.currentRss,
        ));
      }
    } finally {
      recognizer.free();
    }
    return LongRunResult(loadMs: loadMs, rounds: rounds);
  }

  AsrRunResult _runWith(
    so.OnlineRecognizer recognizer,
    Float32List samples, {
    required int sampleRate,
    required int chunkMs,
    required double loadMs,
  }) {
    final stream = recognizer.createStream();
    final events = <AsrEvent>[];
    final utterances = <String>[];
    final chunkDecodeMs = <double>[];
    var decodeCalls = 0;
    var chunks = 0;
    var decodeMs = 0.0;
    var lastText = '';
    var fed = 0;

    final chunkSamples = (sampleRate * chunkMs / 1000).round();
    while (fed < samples.length) {
      final end = (fed + chunkSamples).clamp(0, samples.length);
      final chunk = samples.sublist(fed, end);
      fed = end;
      chunks++;
      final audioMs = (fed * 1000 / sampleRate).round();

      final decodeClock = Stopwatch()..start();
      stream.acceptWaveform(samples: chunk, sampleRate: sampleRate);
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
        decodeCalls++;
      }
      final text = recognizer.getResult(stream).text;
      final endpoint = recognizer.isEndpoint(stream);
      final cost = decodeClock.elapsedMicroseconds / 1000.0;
      decodeMs += cost;
      chunkDecodeMs.add(cost);

      if (text.isNotEmpty && text != lastText) {
        events.add(AsrEvent(
          audioMs: audioMs,
          text: text,
          isFinal: endpoint,
          decodeMs: cost,
        ));
        lastText = text;
      } else if (endpoint && text.isNotEmpty) {
        events.add(AsrEvent(
          audioMs: audioMs,
          text: text,
          isFinal: true,
          decodeMs: cost,
        ));
      }

      if (endpoint) {
        if (text.isNotEmpty) utterances.add(text);
        recognizer.reset(stream);
        lastText = '';
      }
    }

    // 收尾：flush 尾部未出结果的部分。
    stream.inputFinished();
    final flushClock = Stopwatch()..start();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    decodeMs += flushClock.elapsedMicroseconds / 1000.0;
    final tail = recognizer.getResult(stream).text;
    if (tail.isNotEmpty && tail != lastText) {
      events.add(AsrEvent(
        audioMs: samples.length * 1000 ~/ sampleRate,
        text: tail,
        isFinal: true,
        decodeMs: flushClock.elapsedMicroseconds / 1000.0,
      ));
      utterances.add(tail);
    } else if (tail.isNotEmpty) {
      utterances.add(tail);
    }

    stream.free();

    return AsrRunResult(
      events: events,
      audioMs: samples.length * 1000 ~/ sampleRate,
      decodeMs: decodeMs,
      loadMs: loadMs,
      utterances: utterances,
      chunkDecodeMs: chunkDecodeMs,
      decodeCalls: decodeCalls,
      chunks: chunks,
    );
  }
}
