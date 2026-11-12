import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'model_installer.dart';

/// 一条流式识别结果。
class AsrUpdate {
  const AsrUpdate({
    required this.text,
    required this.isFinal,
    required this.decodeMs,
    required this.utteranceElapsedMs,
  });

  /// 当前分句的累积识别文本（不含上一分句）。
  final String text;

  /// 是否由端点检测判定结束（说话人停顿）。
  final bool isFinal;

  /// 本批音频解码耗时。
  final double decodeMs;

  /// 从本分句开始到首次出字的时间（仅首个更新有意义）。
  final double utteranceElapsedMs;
}

/// 解码心跳：只要引擎在消费音频就按固定节拍上报，与是否出字无关。
///
/// 用于区分「采集停止」「引擎无响应」与「真的没说话」：
/// - 没有音频分片 → 采集停；
/// - 有分片但没有心跳 → 引擎停；
/// - 有心跳但没有文本更新 → 静音。
class AsrTick {
  const AsrTick({
    required this.decodeMs,
    required this.isSilent,
    required this.isEndpoint,
    this.processedAudioMs = 0,
    this.decodeTotalMs = 0,
  });

  /// 最近一批音频的解码耗时（ms）。
  final double decodeMs;

  /// 当前分句是否还没有识别文本。
  final bool isSilent;

  /// 是否刚检测到端点（一句结束）。
  final bool isEndpoint;

  /// 解码器已经消费掉的音频总时长（ms，从会话开始累计）。
  ///
  /// 主进程用 `已送入音频 - processedAudioMs` 得到解码队列积压：积压持续
  /// 增长说明解码吞吐跟不上实时，表现就是识别文本与滚动一起卡住。
  final double processedAudioMs;

  /// 解码器累计花在解码上的时间（ms）。与 [processedAudioMs] 一起可算实测 RTF。
  final double decodeTotalMs;
}

class AsrException implements Exception {
  AsrException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 流式识别端点参数（实验面板可切换）。
///
/// 默认值与 sherpa-onnx 2.0.1 的默认值一致，因此不显式配置时行为不变。
class AsrTuning {
  const AsrTuning({
    this.rule1MinTrailingSilence = 2.4,
    this.rule2MinTrailingSilence = 1.2,
  });

  /// 与引擎默认一致（见 `OnlineRecognizerConfig`）。
  static const AsrTuning defaults = AsrTuning();

  /// 规则 1：已解码文本 + 静音多久算一句话结束（秒）。
  final double rule1MinTrailingSilence;

  /// 规则 2：仅静音（无解码文本）多久算一句话结束（秒）。
  final double rule2MinTrailingSilence;

  AsrTuning copyWith({
    double? rule1MinTrailingSilence,
    double? rule2MinTrailingSilence,
  }) {
    return AsrTuning(
      rule1MinTrailingSilence:
          rule1MinTrailingSilence ?? this.rule1MinTrailingSilence,
      rule2MinTrailingSilence:
          rule2MinTrailingSilence ?? this.rule2MinTrailingSilence,
    );
  }

  Map<String, Object?> toJson() => {
        'rule1MinTrailingSilence': rule1MinTrailingSilence,
        'rule2MinTrailingSilence': rule2MinTrailingSilence,
      };

  @override
  String toString() =>
      'AsrTuning(rule1: ${rule1MinTrailingSilence.toStringAsFixed(2)}, '
      'rule2: ${rule2MinTrailingSilence.toStringAsFixed(2)})';
}

/// sherpa-onnx 流式识别（独立 isolate 解码，避免阻塞 UI 线程）。
class SherpaAsrEngine {
  final StreamController<AsrUpdate> _updates =
      StreamController<AsrUpdate>.broadcast();
  final StreamController<AsrTick> _ticks =
      StreamController<AsrTick>.broadcast();

  Isolate? _isolate;
  ReceivePort? _receive;
  ReceivePort? _exitPort;
  ReceivePort? _errorPort;
  SendPort? _send;
  double _lastDecodeMs = 0;
  double _lastUtteranceMs = 0;
  double _fedAudioMs = 0;
  Completer<void>? _flushed;
  bool _started = false;
  bool _disposed = false;
  bool _hasEndpoint = false;
  double loadMs = 0;

  Stream<AsrUpdate> get updates => _updates.stream;

  /// 解码心跳流：引擎在消费音频但未出字时也能观测到「引擎还活着」。
  Stream<AsrTick> get ticks => _ticks.stream;
  bool get isReady => _send != null;
  bool get hasEndpoint => _hasEndpoint;

  Future<void> start(
    InstalledAsrModel model, {
    AsrTuning tuning = AsrTuning.defaults,
    int numThreads = 1,
  }) async {
    if (_started) return;
    _started = true;

    _receive = ReceivePort();
    final ready = Completer<void>();

    _receive!.listen((message) {
      if (message is! Map) return;
      switch (message['type']) {
        case 'ready':
          _send = message['port'] as SendPort;
          loadMs = (message['loadMs'] as num?)?.toDouble() ?? 0;
          if (!ready.isCompleted) ready.complete();
        case 'update':
          _hasEndpoint = message['isFinal'] as bool? ?? false;
          _lastDecodeMs = (message['decodeMs'] as num?)?.toDouble() ?? 0;
          _lastUtteranceMs = (message['utteranceMs'] as num?)?.toDouble() ?? 0;
          _updates.add(
            AsrUpdate(
              text: message['text'] as String? ?? '',
              isFinal: message['isFinal'] as bool? ?? false,
              decodeMs: _lastDecodeMs,
              utteranceElapsedMs: _lastUtteranceMs,
            ),
          );
        case 'tick':
          _lastDecodeMs = (message['decodeMs'] as num?)?.toDouble() ?? 0;
          _lastProcessedAudioMs =
              (message['audioMs'] as num?)?.toDouble() ?? _lastProcessedAudioMs;
          _decodeTotalMs =
              (message['decodeTotalMs'] as num?)?.toDouble() ?? _decodeTotalMs;
          _ticks.add(
            AsrTick(
              decodeMs: _lastDecodeMs,
              isSilent: message['silent'] as bool? ?? true,
              isEndpoint: message['endpoint'] as bool? ?? false,
              processedAudioMs: _lastProcessedAudioMs,
              decodeTotalMs: _decodeTotalMs,
            ),
          );
        case 'flushed':
          if (message['text'] is String &&
              (message['text'] as String).isNotEmpty) {
            _updates.add(
              AsrUpdate(
                text: message['text'] as String,
                isFinal: true,
                decodeMs: _lastDecodeMs,
                utteranceElapsedMs: _lastUtteranceMs,
              ),
            );
          }
          if (_flushed != null && !_flushed!.isCompleted) _flushed!.complete();
        case 'error':
          if (!ready.isCompleted) {
            ready.completeError(AsrException(message['message'] as String));
          }
      }
    });

    // 解码 isolate 一旦异常退出，主进程的 send 会静默落到死端口：
    // 更新与心跳同时停止，UI 表现为「识别文本与滚动一起冻住」。
    // 必须显式监听退出与未捕获异常，把它变成可上报的错误。
    _exitPort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort!.listen((_) => _reportEngineDied('识别引擎 isolate 已退出'));
    _errorPort!.listen((message) {
      _reportEngineDied(
          '识别引擎未捕获异常: ${message is List ? message.first : message}');
    });

    _isolate = await Isolate.spawn<List<dynamic>>(
      _asrIsolateEntry,
      [
        _receive!.sendPort,
        model.encoder,
        model.decoder,
        model.joiner,
        model.tokens,
        model.spec.modelType,
        numThreads,
        tuning.rule1MinTrailingSilence,
        tuning.rule2MinTrailingSilence,
      ],
      debugName: 'sherpa-asr',
    );
    _isolate!.addErrorListener(_errorPort!.sendPort);
    _isolate!.addOnExitListener(_exitPort!.sendPort);

    await ready.future.timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw AsrException('ASR 模型加载超时'),
    );
  }

  void accept(Float32List samples) {
    if (!isReady || _disposed || samples.isEmpty) return;
    _fedAudioMs += samples.length * 1000.0 / 16000.0;
    _send!.send({
      'cmd': 'samples',
      'data': TransferableTypedData.fromList([samples.buffer.asUint8List()]),
    });
  }

  /// 已送入解码器的音频总时长（ms）。
  double get fedAudioMs => _fedAudioMs;

  /// 解码 isolate 是否已经退出（退出后 accept 不再有效）。
  bool get engineDied => _engineDied;
  bool _engineDied = false;

  /// 把 isolate 死亡转成一次可见错误：UI 不再只是"静默卡住"。
  ///
  /// 只在非主动 dispose 时上报，且只报一次（退出与错误监听可能都触发）。
  void _reportEngineDied(String message) {
    if (_engineDied) return;
    _engineDied = true;
    _send = null;
    if (!_disposed && !_updates.isClosed) {
      _updates.addError(AsrException(message));
    }
  }

  /// 解码队列积压（ms）= 已送入 - 解码器已消费。持续增长即吞吐不足。
  double get backlogMs {
    final processed = _lastProcessedAudioMs;
    final lag = _fedAudioMs - processed;
    return lag < 0 ? 0 : lag;
  }

  double _lastProcessedAudioMs = 0;
  double _decodeTotalMs = 0;

  /// 累计解码耗时（ms），配合 [AsrTick.processedAudioMs] 算 RTF。
  double get decodeTotalMs => _decodeTotalMs;

  /// 把剩余音频解码完并等到 `flushed`（离线吞吐测量用）。
  Future<void> flush() async {
    if (!isReady) return;
    final completer = Completer<void>();
    _flushed = completer;
    _send!.send({'cmd': 'finish'});
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => _flushed = null,
    );
  }

  Future<void> finish() async {
    if (!isReady) return;
    _send!.send({'cmd': 'finish'});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _send?.send({'cmd': 'dispose'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _send = null;
    _receive?.close();
    _exitPort?.close();
    _exitPort = null;
    _errorPort?.close();
    _errorPort = null;
    await _updates.close();
    await _ticks.close();
  }
}

void _asrIsolateEntry(List<dynamic> args) async {
  final mainPort = args[0] as SendPort;
  final encoder = args[1] as String;
  final decoder = args[2] as String;
  final joiner = args[3] as String;
  final tokens = args[4] as String;
  final modelType = args[5] as String;
  final numThreads = args[6] as int;
  final rule1MinTrailingSilence = (args[7] as num).toDouble();
  final rule2MinTrailingSilence = (args[8] as num).toDouble();

  final commandPort = ReceivePort();
  final clock = Stopwatch()..start();

  so.OnlineRecognizer? recognizer;
  so.OnlineStream? stream;
  var utteranceStartMs = 0.0;
  var lastText = '';
  var lastTickMs = 0.0;
  var processedSamples = 0;
  var decodeTotalMs = 0.0;

  void emit({
    required String text,
    required bool isFinal,
    required double decodeMs,
  }) {
    mainPort.send({
      'type': 'update',
      'text': text,
      'isFinal': isFinal,
      'decodeMs': decodeMs,
      'utteranceMs': clock.elapsedMicroseconds / 1000.0 - utteranceStartMs,
    });
  }

  try {
    so.initBindings();
    final loadClock = Stopwatch()..start();
    recognizer = so.OnlineRecognizer(
      so.OnlineRecognizerConfig(
        model: so.OnlineModelConfig(
          transducer: so.OnlineTransducerModelConfig(
            encoder: encoder,
            decoder: decoder,
            joiner: joiner,
          ),
          tokens: tokens,
          numThreads: numThreads,
          modelType: modelType,
        ),
        rule1MinTrailingSilence: rule1MinTrailingSilence,
        rule2MinTrailingSilence: rule2MinTrailingSilence,
      ),
    );
    stream = recognizer.createStream();
    utteranceStartMs = clock.elapsedMicroseconds / 1000.0;

    mainPort.send({
      'type': 'ready',
      'port': commandPort.sendPort,
      'loadMs': loadClock.elapsedMilliseconds,
    });
  } catch (error) {
    mainPort.send({'type': 'error', 'message': '识别器初始化失败: $error'});
    commandPort.close();
    return;
  }

  void process(Float32List? samples) {
    final decodeClock = Stopwatch()..start();
    if (samples != null) {
      processedSamples += samples.length;
      stream!.acceptWaveform(samples: samples, sampleRate: 16000);
    }
    while (recognizer!.isReady(stream!)) {
      recognizer.decode(stream);
    }
    final text = recognizer.getResult(stream).text;
    final endpoint = recognizer.isEndpoint(stream);

    if (text.isNotEmpty && text != lastText) {
      emit(
        text: text,
        isFinal: endpoint,
        decodeMs: decodeClock.elapsedMicroseconds / 1000.0,
      );
      lastText = text;
    } else if (endpoint && text.isNotEmpty) {
      emit(
        text: text,
        isFinal: true,
        decodeMs: decodeClock.elapsedMicroseconds / 1000.0,
      );
      lastText = text;
    }

    if (endpoint) {
      recognizer.reset(stream);
      lastText = '';
      utteranceStartMs = clock.elapsedMicroseconds / 1000.0;
    }

    // 心跳与是否出字无关：主进程据此判断引擎是否还在消费音频。
    decodeTotalMs += decodeClock.elapsedMicroseconds / 1000.0;
    final nowMs = clock.elapsedMicroseconds / 1000.0;
    if (nowMs - lastTickMs >= 500) {
      lastTickMs = nowMs;
      mainPort.send({
        'type': 'tick',
        'decodeMs': decodeClock.elapsedMicroseconds / 1000.0,
        'silent': text.isEmpty,
        'endpoint': endpoint,
        'audioMs': processedSamples * 1000.0 / 16000.0,
        'decodeTotalMs': decodeTotalMs,
      });
    }
  }

  commandPort.listen((message) {
    if (message is! Map) return;
    switch (message['cmd']) {
      case 'samples':
        final buffer = (message['data'] as TransferableTypedData).materialize();
        process(Float32List.view(buffer, 0, buffer.lengthInBytes ~/ 4));
      case 'finish':
        final streamNow = stream;
        final recognizerNow = recognizer;
        if (streamNow == null || recognizerNow == null) {
          mainPort.send({'type': 'flushed', 'text': ''});
          break;
        }
        try {
          streamNow.inputFinished();
          while (recognizerNow.isReady(streamNow)) {
            recognizerNow.decode(streamNow);
          }
          mainPort.send({
            'type': 'flushed',
            'text': recognizerNow.getResult(streamNow).text,
          });
        } catch (_) {
          mainPort.send({'type': 'flushed', 'text': ''});
        }
      case 'dispose':
        commandPort.close();
        break;
    }
  });
}
