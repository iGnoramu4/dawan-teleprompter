import 'dart:io';

import 'package:asr_kit/asr_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 用内存数据代替真实 assets，便于构造解包中途失败。
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, Uint8List> files;
  final List<String> loads = [];

  /// 命中该文件时模拟读盘/写盘失败（丢掉半成品）。
  String? failOn;

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final name = p.basename(key);
    if (failOn == name) {
      throw FileSystemException('injected write failure', key);
    }
    final bytes = files[key];
    if (bytes == null) {
      throw StateError('missing asset $key');
    }
    return ByteData.sublistView(bytes);
  }
}

const _encoder = 'encoder.onnx';
const _decoder = 'decoder.onnx';
const _joiner = 'joiner.onnx';
const _tokens = 'tokens.txt';

const _encoderBytes = 5 * 1024 * 1024 + 123; // 跨两个 4 MB 分块
const _decoderBytes = 1024 * 1024;
const _joinerBytes = 2 * 1024 * 1024;
const _tokensBytes = 40;
const _totalBytes = _encoderBytes + _decoderBytes + _joinerBytes + _tokensBytes;

AsrModelSpec _spec() => const AsrModelSpec(
      id: 'test-model',
      assetDir: 'assets/models/test-model',
      encoderFile: _encoder,
      decoderFile: _decoder,
      joinerFile: _joiner,
      tokensFile: _tokens,
      fileBytes: {
        _encoder: _encoderBytes,
        _decoder: _decoderBytes,
        _joiner: _joinerBytes,
        _tokens: _tokensBytes,
      },
    );

_FakeBundle _bundle() => _FakeBundle({
      'assets/models/test-model/$_encoder': Uint8List(_encoderBytes),
      'assets/models/test-model/$_decoder': Uint8List(_decoderBytes),
      'assets/models/test-model/$_joiner': Uint8List(_joinerBytes),
      'assets/models/test-model/$_tokens': Uint8List(_tokensBytes),
    });

Directory _modelDir(Directory support) =>
    Directory(p.join(support.path, 'asr_models', 'test-model'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('model_installer_test');
    support = Directory(p.join(tmp.path, 'support'))
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('进度按真实写盘量推进：单调递增、百分比收敛到 100', () async {
    final bundle = _bundle();
    final progresses = <ModelInstallProgress>[];
    var starts = 0;

    final model = await ModelInstaller.ensure(
      _spec(),
      onStart: () => starts++,
      onProgress: progresses.add,
      supportDir: () async => support,
      bundle: bundle,
    );

    expect(starts, 1);
    expect(model.freshlyInstalled, isTrue);
    expect(model.dir, _modelDir(support).path);
    expect(progresses, isNotEmpty);
    // 4 MB 分块：5 MB 的 encoder 至少产生两次进度。
    expect(
      progresses.map((e) => e.currentFile).toSet(),
      {_encoder, _decoder, _joiner, _tokens},
    );
    for (var i = 1; i < progresses.length; i++) {
      expect(
        progresses[i].bytesDone,
        greaterThan(progresses[i - 1].bytesDone),
      );
    }
    final last = progresses.last;
    expect(last.bytesDone, _totalBytes);
    expect(last.bytesTotal, _totalBytes);
    expect(last.percent, 100);
    expect(last.doneMb, last.totalMb);
    expect(progresses.first.percent, lessThan(100));
    expect(File(p.join(model.dir, '.installed-v1')).existsSync(), isTrue);
    for (final name in _spec().files) {
      final file = File(p.join(model.dir, name));
      expect(file.existsSync(), isTrue, reason: name);
      expect(file.lengthSync(), _spec().fileBytes[name], reason: name);
    }
  });

  test('已安装时二次调用不再上报解包进度，也不重复读 assets', () async {
    final bundle = _bundle();
    await ModelInstaller.ensure(
      _spec(),
      supportDir: () async => support,
      bundle: bundle,
    );
    final loadsAfterFirst = bundle.loads.length;

    var starts = 0;
    final progresses = <ModelInstallProgress>[];
    final second = await ModelInstaller.ensure(
      _spec(),
      onStart: () => starts++,
      onProgress: progresses.add,
      supportDir: () async => support,
      bundle: bundle,
    );

    expect(second.freshlyInstalled, isFalse);
    expect(starts, 0);
    expect(progresses, isEmpty);
    expect(bundle.loads.length, loadsAfterFirst);
  });

  test('解包中途失败清理半成品，并可在同一路径重试成功', () async {
    final bundle = _bundle()..failOn = _joiner;
    final dir = _modelDir(support);

    await expectLater(
      ModelInstaller.ensure(
        _spec(),
        supportDir: () async => support,
        bundle: bundle,
      ),
      throwsA(
        isA<ModelInstallException>()
            .having((e) => e.file, 'file', _joiner)
            .having((e) => e.cleaned, 'cleaned', isTrue),
      ),
    );
    // 失败前已写入的 encoder/decoder 也必须一并删除，不能留下“看似已安装”的目录。
    expect(dir.existsSync(), isFalse);

    bundle.failOn = null;
    final retried = await ModelInstaller.ensure(
      _spec(),
      supportDir: () async => support,
      bundle: bundle,
    );
    expect(retried.freshlyInstalled, isTrue);
    expect(File(p.join(dir.path, _joiner)).lengthSync(), _joinerBytes);
  });

  test('写盘路径不可创建时抛出安装失败并标记已清理', () async {
    // 用同名文件占住 asr_models 目录，构造真实的目录创建失败。
    File(p.join(support.path, 'asr_models')).writeAsStringSync('blocked');

    await expectLater(
      ModelInstaller.ensure(
        _spec(),
        supportDir: () async => support,
        bundle: _bundle(),
      ),
      throwsA(
        isA<ModelInstallException>()
            .having((e) => e.cleaned, 'cleaned', isTrue)
            .having((e) => e.cause, 'cause', isA<FileSystemException>()),
      ),
    );
    expect(_modelDir(support).existsSync(), isFalse);
  });

  test('进度对象边界：分母为 0 与超出总字节都收敛在 0–100%', () {
    const zero = ModelInstallProgress(
      bytesDone: 0,
      bytesTotal: 0,
      currentFile: _tokens,
    );
    const over = ModelInstallProgress(
      bytesDone: 2048 * 1024,
      bytesTotal: 1024 * 1024,
      currentFile: _encoder,
    );
    expect(zero.fraction, 0);
    expect(zero.percent, 0);
    expect(over.fraction, 1);
    expect(over.percent, 100);
    expect(over.doneMb, 2);
    expect(over.totalMb, 1);
  });
}
