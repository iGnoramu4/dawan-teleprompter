import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 一个位流式识别模型在 assets 中的文件清单。
class AsrModelSpec {
  const AsrModelSpec({
    required this.id,
    required this.assetDir,
    required this.encoderFile,
    required this.decoderFile,
    required this.joinerFile,
    required this.tokensFile,
    this.fileBytes = const {},
    this.modelType = '',
  });

  final String id;
  final String assetDir;
  final String encoderFile;
  final String decoderFile;
  final String joinerFile;
  final String tokensFile;

  /// 各文件字节数（与 `tool/models.lock.json` 一致），仅用于首次解包进度。
  final Map<String, int> fileBytes;

  /// 留空表示由 sherpa-onnx 读取模型元数据自动判断。
  final String modelType;

  List<String> get files => [encoderFile, decoderFile, joinerFile, tokensFile];

  /// 四个文件合计字节数；缺项按 0 计（仅影响进度分母）。
  int get totalBytes =>
      files.fold(0, (sum, name) => sum + (fileBytes[name] ?? 0));

  /// T0 档：sherpa-onnx streaming zipformer zh 14M（int8，约 25 MB）。
  static const zh14mInt8 = AsrModelSpec(
    id: 'zipformer-zh-14M-int8',
    assetDir: 'assets/models/zipformer-zh-14M-int8',
    encoderFile: 'encoder-epoch-99-avg-1.int8.onnx',
    decoderFile: 'decoder-epoch-99-avg-1.int8.onnx',
    joinerFile: 'joiner-epoch-99-avg-1.int8.onnx',
    tokensFile: 'tokens.txt',
    fileBytes: {
      'encoder-epoch-99-avg-1.int8.onnx': 21621684,
      'decoder-epoch-99-avg-1.int8.onnx': 1888682,
      'joiner-epoch-99-avg-1.int8.onnx': 1795562,
      'tokens.txt': 48697,
    },
  );

  /// T1 档：中英双语 zipformer（encoder int8 + decoder/joiner fp32，约 209 MB）。
  ///
  /// 全 int8 版本会系统性叠字，只有 decoder/joiner 保留 fp32 才可用；
  /// 详细对照见 docs/design/20261110-bilingual-zipformer-plan.md。
  static const zipformerBilingualMixed = AsrModelSpec(
    id: 'zipformer-bilingual-mixed',
    assetDir: 'assets/models/zipformer-bilingual-mixed',
    encoderFile: 'encoder-epoch-99-avg-1.int8.onnx',
    decoderFile: 'decoder-epoch-99-avg-1.onnx',
    joinerFile: 'joiner-epoch-99-avg-1.onnx',
    tokensFile: 'tokens.txt',
    fileBytes: {
      'encoder-epoch-99-avg-1.int8.onnx': 181895032,
      'decoder-epoch-99-avg-1.onnx': 13876452,
      'joiner-epoch-99-avg-1.onnx': 12833618,
      'tokens.txt': 56317,
    },
  );
}

/// 首次解包进度：字节数来自真实写盘量，不是定时器估算。
class ModelInstallProgress {
  const ModelInstallProgress({
    required this.bytesDone,
    required this.bytesTotal,
    required this.currentFile,
  });

  final int bytesDone;
  final int bytesTotal;

  /// 正在写入的文件名（仅用于诊断与日志）。
  final String currentFile;

  double get fraction =>
      bytesTotal <= 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  int get doneMb => bytesDone ~/ (1024 * 1024);

  int get totalMb => bytesTotal ~/ (1024 * 1024);
}

/// 解包失败：抛出前已尝试删除半成品目录（`cleaned` 记录是否删干净）。
class ModelInstallException implements Exception {
  const ModelInstallException({
    required this.file,
    required this.cause,
    required this.cleaned,
  });

  final String file;
  final Object cause;
  final bool cleaned;

  @override
  String toString() =>
      'ModelInstallException(file=$file, cleaned=$cleaned): $cause';
}

/// 首次启动时把模型从 assets 解包到应用私有目录，之后离线直接读取。
class InstalledAsrModel {
  const InstalledAsrModel({
    required this.spec,
    required this.dir,
    this.freshlyInstalled = false,
  });

  final AsrModelSpec spec;
  final String dir;

  /// 本次调用是否真的解包（false = 命中已有安装）。
  final bool freshlyInstalled;

  String get encoder => p.join(dir, spec.encoderFile);
  String get decoder => p.join(dir, spec.decoderFile);
  String get joiner => p.join(dir, spec.joinerFile);
  String get tokens => p.join(dir, spec.tokensFile);
}

class ModelInstaller {
  static const String _marker = '.installed-v1';

  /// 单次写盘分块（4 MB）：进度按真实写入量推进。
  static const int _chunkBytes = 4 << 20;

  /// 确保模型可用；首次调用会解包并按 [onProgress] 上报真实进度。
  ///
  /// 已安装时直接返回，不触发 [onStart]/[onProgress]（避免二次启动误显示解包）。
  /// [onStart] 只在确实需要解包时回调一次，用于把「解包」与「加载」两阶段分开。
  /// 失败时删除半成品目录并抛 [ModelInstallException]，下次调用可重新解包。
  static Future<InstalledAsrModel> ensure(
    AsrModelSpec spec, {
    void Function()? onStart,
    void Function(ModelInstallProgress progress)? onProgress,
    Future<Directory> Function()? supportDir,
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    var current = '';
    Directory? dir;
    final total = spec.totalBytes;
    var done = 0;
    try {
      dir = await _modelDir(spec, supportDir);
      final marker = File(p.join(dir.path, _marker));
      if (marker.existsSync()) {
        return InstalledAsrModel(spec: spec, dir: dir.path);
      }
      onStart?.call();

      // 上次中断留下的半成品先清掉，避免脏文件混入本次安装。
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      for (final name in spec.files) {
        current = name;
        final data = await assets.load('${spec.assetDir}/$name');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final sink = File(p.join(dir.path, name)).openWrite();
        try {
          for (var offset = 0; offset < bytes.length; offset += _chunkBytes) {
            final end = math.min(offset + _chunkBytes, bytes.length);
            sink.add(bytes.sublist(offset, end));
            await sink.flush();
            done += end - offset;
            onProgress?.call(
              ModelInstallProgress(
                bytesDone: done,
                bytesTotal: math.max(total, done),
                currentFile: name,
              ),
            );
          }
        } finally {
          await sink.close();
        }
      }
      await marker.writeAsString('ok');
    } catch (error) {
      // 失败即清理半成品，避免下次被 marker 误判为已安装。
      var cleaned = false;
      try {
        if (dir != null && dir.existsSync()) {
          await dir.delete(recursive: true);
        }
        cleaned = dir == null || !dir.existsSync();
      } catch (_) {
        cleaned = false;
      }
      throw ModelInstallException(
        file: current,
        cause: error,
        cleaned: cleaned,
      );
    }
    return InstalledAsrModel(spec: spec, dir: dir.path, freshlyInstalled: true);
  }

  static Future<Directory> _modelDir(
    AsrModelSpec spec,
    Future<Directory> Function()? supportDir,
  ) async {
    final support = await (supportDir ?? getApplicationSupportDirectory)();
    return Directory(p.join(support.path, 'asr_models', spec.id));
  }
}
