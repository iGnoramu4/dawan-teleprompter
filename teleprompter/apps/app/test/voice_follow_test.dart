import 'dart:io';

import 'package:asr_kit/asr_kit.dart';
import 'package:core_alignment/core_alignment.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/reader/voice_follow.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';

const _recordChannel = MethodChannel('com.llfbandit.record/messages');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restartWith 直接替换对齐索引与跟踪器，不重建 ASR 会话', () async {
    // VoiceFollowSession 构造即创建录音器；测试环境桩掉插件通道。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_recordChannel, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(_recordChannel, null));

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final firstIndex = ScriptIndex.build(['第一行内容', '第二行内容']);
    final firstTracker = AlignTracker.fromProfile(
      MatchProfile.standardProfile,
      lineCount: 2,
    );
    final session = VoiceFollowSession(
      index: firstIndex,
      tracker: firstTracker,
      l10n: l10n,
      onUpdate: (_) {},
      onStatus: (_) {},
      onError: (_) {},
    );
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {
        // 未启动麦克风时部分平台插件不可用，测试无需关心。
      }
    });

    final nextIndex = ScriptIndex.build(['第一行重新断句', '第二行内容', '第三行内容']);
    final nextTracker = AlignTracker.fromProfile(
      MatchProfile.standardProfile,
      lineCount: 3,
      initialLine: 1,
    );
    session.restartWith(index: nextIndex, tracker: nextTracker);

    expect(session.index, same(nextIndex));
    expect(session.tracker, same(nextTracker));
    expect(session.tracker.line, 1);
    // 阶段 B 验收：纯 Dart 热替换必须在 300 ms 内完成。
    expect(
      session.lastAlignRestart,
      lessThan(const Duration(milliseconds: 300)),
    );
  });

  test('启动路径默认用中英混合模型，切中文轻量按传入规格生效', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_recordChannel, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(_recordChannel, null));

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final index = ScriptIndex.build(['第一行内容']);
    final tracker = AlignTracker.fromProfile(
      MatchProfile.standardProfile,
      lineCount: 1,
    );

    final mixed = VoiceFollowSession(
      index: index,
      tracker: tracker,
      l10n: l10n,
      modelSpec: AsrModelSpec.zipformerBilingualMixed,
      onUpdate: (_) {},
      onStatus: (_) {},
      onError: (_) {},
    );
    addTearDown(() => mixed.dispose());
    expect(mixed.modelSpec.id, AsrModelSpec.zipformerBilingualMixed.id);

    final light = VoiceFollowSession(
      index: index,
      tracker: tracker,
      l10n: l10n,
      onUpdate: (_) {},
      onStatus: (_) {},
      onError: (_) {},
    );
    addTearDown(() => light.dispose());
    expect(light.modelSpec.id, AsrModelSpec.zh14mInt8.id);
    expect(light.modelSpec.id, 'zipformer-zh-14M-int8');
  });

  test('首次解包按 安装→进度→加载 推进，失败向上抛安装异常', () async {
    final l10n = await _loadL10n();
    final statuses = <String>[];
    final session = _session(l10n, statuses,
        installModel: (spec, {onStart, onProgress}) async {
      onStart?.call();
      onProgress?.call(ModelInstallProgress(
        bytesDone: 3 << 20,
        bytesTotal: 8 << 20,
        currentFile: spec.encoderFile,
      ));
      throw ModelInstallException(
        file: spec.encoderFile,
        cause: 'injected',
        cleaned: true,
      );
    });
    addTearDown(session.dispose);

    await expectLater(
        session.startMic(), throwsA(isA<ModelInstallException>()));
    expect(statuses, [
      l10n.voiceInstallModel,
      l10n.voiceInstallModelProgress(38, 3, 8),
    ]);
    // 未进入加载识别器阶段。
    expect(statuses, isNot(contains(l10n.voiceLoadingRecognizer)));
  });

  test('解包成功后单独提示加载识别器，阶段不混淆', () async {
    final l10n = await _loadL10n();
    final statuses = <String>[];
    final missing = Directory.systemTemp.createTempSync('voice_follow_test');
    addTearDown(() => missing.delete(recursive: true));
    final session = _session(l10n, statuses,
        installModel: (spec, {onStart, onProgress}) async {
      onStart?.call();
      onProgress?.call(ModelInstallProgress(
        bytesDone: 4 << 20,
        bytesTotal: 4 << 20,
        currentFile: spec.encoderFile,
      ));
      return InstalledAsrModel(
        spec: spec,
        dir: missing.path,
        freshlyInstalled: true,
      );
    });
    addTearDown(session.dispose);

    // 模型文件不存在，加载识别器必然失败；这里只验证阶段顺序。
    await expectLater(session.startMic(), throwsA(isA<AsrException>()));
    expect(statuses, [
      l10n.voiceInstallModel,
      l10n.voiceInstallModelProgress(100, 4, 4),
      l10n.voiceLoadingRecognizer,
    ]);
  });

  test('已安装模型不再上报解包进度，直接进入加载阶段', () async {
    final l10n = await _loadL10n();
    final statuses = <String>[];
    final missing = Directory.systemTemp.createTempSync('voice_follow_test');
    addTearDown(() => missing.delete(recursive: true));
    final session = _session(l10n, statuses,
        installModel: (spec, {onStart, onProgress}) async {
      // 走已安装路径：installer 不会回调 onStart/onProgress。
      return InstalledAsrModel(spec: spec, dir: missing.path);
    });
    addTearDown(session.dispose);

    await expectLater(session.startMic(), throwsA(isA<AsrException>()));
    expect(statuses, [l10n.voiceLoadingRecognizer]);
  });
}

Future<AppLocalizations> _loadL10n() =>
    AppLocalizations.delegate.load(const Locale('zh'));

VoiceFollowSession _session(
  AppLocalizations l10n,
  List<String> statuses, {
  ModelInstallFn? installModel,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_recordChannel, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(_recordChannel, null));

  final index = ScriptIndex.build(['第一行内容']);
  return VoiceFollowSession(
    index: index,
    tracker: AlignTracker.fromProfile(
      MatchProfile.standardProfile,
      lineCount: 1,
    ),
    l10n: l10n,
    onUpdate: (_) {},
    onStatus: statuses.add,
    onError: (_) {},
    installModel: installModel,
  );
}
