import 'package:core_alignment/core_alignment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';

void main() {
  test('默认参数在合法范围内', () {
    final defaults = ReaderSettings.defaults.normalized();
    expect(defaults.fontSize, 44);
    expect(defaults.theme, ReaderTheme.stageDark);
    expect(defaults.speed, 1.2);
    expect(defaults.matchTolerance, MatchTolerance.standard);
  });

  test('JSON 往返保留全部参数', () {
    const settings = ReaderSettings(
      theme: ReaderTheme.stageWhite,
      fontSize: 72,
      lineHeight: 2.0,
      leftMargin: 0.18,
      rightMargin: 0.22,
      matchTolerance: MatchTolerance.loose,
      alignCenter: true,
      mirrorX: true,
      mirrorY: true,
      prismDx: 0.02,
      prismDy: -0.03,
      speed: 3.4,
      readAheadRatio: 0.45,
      smoothness: 11,
      pauseStop: false,
      keepScreenOn: false,
      lineStepFollow: false,
    );
    final restored = ReaderSettings.fromJson(settings.toJson());
    expect(restored.theme, ReaderTheme.stageWhite);
    expect(restored.fontSize, 72);
    expect(restored.lineHeight, 2.0);
    expect(restored.leftMargin, 0.18);
    expect(restored.rightMargin, 0.22);
    expect(restored.matchTolerance, MatchTolerance.loose);
    expect(restored.alignCenter, isTrue);
    expect(restored.mirrorX, isTrue);
    expect(restored.mirrorY, isTrue);
    expect(restored.prismDx, closeTo(0.02, 1e-9));
    expect(restored.prismDy, closeTo(-0.03, 1e-9));
    expect(restored.speed, 3.4);
    expect(restored.readAheadRatio, 0.45);
    expect(restored.smoothness, 11);
    expect(restored.pauseStop, isFalse);
    expect(restored.keepScreenOn, isFalse);
    expect(restored.lineStepFollow, isFalse);
  });

  test('旧预设的每行字数被忽略，不报错', () {
    final restored = ReaderSettings.fromJson({
      'fontSize': 60,
      'maxLineChars': 24,
      'matchTolerance': 'strict',
    });
    expect(restored.fontSize, 60);
    expect(restored.matchTolerance, MatchTolerance.strict);
    expect(restored.toJson().containsKey('maxLineChars'), isFalse);
    expect(restored.toJson()['matchTolerance'], 'strict');
  });

  test('未知档位回落到标准档', () {
    expect(
      ReaderSettings.fromJson({'matchTolerance': 'aggressive'}).matchTolerance,
      MatchTolerance.standard,
    );
    expect(
      ReaderSettings.fromJson({'matchTolerance': 42}).matchTolerance,
      MatchTolerance.standard,
    );
  });

  test('越界值被归一化', () {
    final restored = ReaderSettings.fromJson({
      'fontSize': 400,
      'lineHeight': 0.2,
      'leftMargin': -1,
      'rightMargin': 1,
      'speed': 99,
      'smoothness': 0,
      'prismDx': 1,
      'theme': 'unknown',
    });
    expect(restored.fontSize, 160);
    expect(restored.lineHeight, 1.0);
    expect(restored.leftMargin, 0);
    expect(restored.rightMargin, 0.4);
    expect(restored.speed, 10);
    expect(restored.smoothness, 4);
    expect(restored.prismDx, 0.05);
    expect(restored.theme, ReaderTheme.stageDark);
  });

  test('行距越大行间距越大', () {
    const tight = ReaderSettings(lineHeight: 1.0);
    const loose = ReaderSettings(lineHeight: 2.5);
    expect(loose.lineGapFor(48), greaterThan(tight.lineGapFor(48)));
  });

  test('逐行跟随默认开启，可从旧数据回退', () {
    expect(ReaderSettings.defaults.lineStepFollow, isTrue);
    expect(
      ReaderSettings.fromJson({'fontSize': 44}).lineStepFollow,
      isTrue,
    );
  });

  test('画布宽度按左右边距收窄并封顶 980', () {
    const settings = ReaderSettings(leftMargin: 0.12, rightMargin: 0.12);
    expect(settings.stageWidthFor(800), closeTo(800 * 0.76, 1e-9));
    expect(settings.stageWidthFor(2000), 980);
    expect(
      const ReaderSettings(leftMargin: 0, rightMargin: 0).stageWidthFor(600),
      600,
    );
    expect(
      const ReaderSettings(leftMargin: 0.2, rightMargin: 0.2)
          .stageWidthFor(600),
      closeTo(360, 1e-9),
    );
  });

  test('左右边距不等时按左缘偏移定位画布', () {
    const settings = ReaderSettings(leftMargin: 0.1, rightMargin: 0.3);
    expect(settings.stageWidthFor(1000), closeTo(600, 1e-9));
    expect(settings.stageLeftFor(1000), closeTo(100, 1e-9));
  });

  test('宽度封顶后剩余空间居中', () {
    const settings = ReaderSettings(leftMargin: 0.1, rightMargin: 0.1);
    // 可用 1600，封顶 980，左缘 = 200 + (1600-980)/2。
    expect(settings.stageLeftFor(2000), closeTo(510, 1e-9));
  });

  test('缺省或未知识别模型回落到中文轻量 14M', () {
    expect(
      ReaderSettings.fromJson({'fontSize': 44}).asrModel,
      AsrModelChoice.zh14m,
    );
    expect(ReaderSettings.defaults.asrModel, AsrModelChoice.zh14m);
    expect(
      ReaderSettings.fromJson({'asrModel': 'bilingualMixed'}).asrModel,
      AsrModelChoice.bilingualMixed,
    );
  });

  test('旧三档宽松度直接映射到新五档同名档', () {
    for (final name in ['strict', 'standard', 'loose']) {
      final restored = ReaderSettings.fromJson({'matchTolerance': name});
      expect(restored.matchTolerance.name, name);
    }
  });

  test('fromRaw 解析字符串并拒绝非法内容', () {
    final raw = ReaderSettings.defaults
        .copyWith(fontSize: 66, theme: ReaderTheme.stageWhite)
        .toJsonString();
    final restored = ReaderSettings.fromRaw(raw);
    expect(restored.fontSize, 66);
    expect(restored.theme, ReaderTheme.stageWhite);
    expect(() => ReaderSettings.fromRaw('[]'), throwsFormatException);
  });

  test('mirrorAny 与 toString 覆盖镜像组合', () {
    expect(const ReaderSettings().mirrorAny, isFalse);
    expect(const ReaderSettings(mirrorX: true).mirrorAny, isTrue);
    expect(const ReaderSettings(mirrorY: true).mirrorAny, isTrue);
    expect(
      const ReaderSettings(mirrorX: true, mirrorY: true).mirrorAny,
      isTrue,
    );
    expect(const ReaderSettings().toString(), contains('fontSize'));
  });

  test('新建台本默认紧凑排版与固定阅读带参数', () {
    const defaults = ReaderSettings.defaults;
    expect(defaults.lineHeight, 1.55);
    expect(defaults.endBehavior, ReaderEndBehavior.stop);
    expect(defaults.readAheadRatio, closeTo(0.34, 1e-9));
  });

  test('旧预设按旧实际行距迁移，打开不变样', () {
    final restored = ReaderSettings.fromJson({'lineHeight': 1.5});
    // 1.5 + 0.28（内边距）+ 0.55（行间距）≈ 2.33
    expect(restored.lineHeight, closeTo(2.33, 1e-9));
    expect(
      ReaderSettings.legacyLineHeightToPitch(1.5),
      closeTo(2.33, 1e-9),
    );
  });

  test('新排版模型往返不触发迁移', () {
    const settings = ReaderSettings();
    final json = settings.toJson();
    expect(json[ReaderSettings.typographyModelKey], 2);
    expect(ReaderSettings.fromJson(json).lineHeight, 1.55);
  });

  test('篇尾行为可持久化', () {
    const settings = ReaderSettings(endBehavior: ReaderEndBehavior.loop);
    final restored = ReaderSettings.fromJson(settings.toJson());
    expect(restored.endBehavior, ReaderEndBehavior.loop);
  });

  test('旧预设里的已移除开关被忽略，且不再写回', () {
    final migrated = ReaderSettings.fromJson({
      'fontSize': 44,
      'phoneticMatch': false,
      'highlightEnabled': false,
      'showNextLine': false,
      'classicHighlight': true,
    });
    expect(migrated.fontSize, 44);
    final json = migrated.toJson();
    expect(json.containsKey('phoneticMatch'), isFalse);
    expect(json.containsKey('highlightEnabled'), isFalse);
    expect(json.containsKey('showNextLine'), isFalse);
    expect(json.containsKey('classicHighlight'), isFalse);
  });

  test('延迟补偿默认开启，可关闭并往返持久化', () {
    expect(ReaderSettings.defaults.latencyCompensation, isTrue);
    expect(
      ReaderSettings.fromJson({'fontSize': 44}).latencyCompensation,
      isTrue,
    );
    final switched =
        ReaderSettings.defaults.copyWith(latencyCompensation: false);
    expect(switched.toJson()['latencyCompensation'], isFalse);
    expect(
      ReaderSettings.fromJson(switched.toJson()).latencyCompensation,
      isFalse,
    );
  });

  test('识别模型默认中文轻量，可切中英混合且往返不丢', () {
    expect(ReaderSettings.defaults.asrModel, AsrModelChoice.zh14m);
    final switched = ReaderSettings.defaults
        .copyWith(asrModel: AsrModelChoice.bilingualMixed);
    expect(switched.asrModel, AsrModelChoice.bilingualMixed);
    expect(switched.toJson()['asrModel'], 'bilingualMixed');
    expect(ReaderSettings.fromJson(switched.toJson()).asrModel,
        AsrModelChoice.bilingualMixed);
    expect(ReaderSettings.fromJson({'asrModel': 'zh14m'}).asrModel,
        AsrModelChoice.zh14m);
  });

  test('预设缺少或包含未知识别模型时回落到中文轻量', () {
    final legacy = <String, Object?>{
      'fontSize': 60,
      'theme': 'stageWhite',
      'lineStepFollow': false,
    };
    final restored = ReaderSettings.fromJson(legacy);
    expect(restored.asrModel, AsrModelChoice.zh14m);
    expect(restored.fontSize, 60);
    expect(restored.theme, ReaderTheme.stageWhite);
    expect(restored.lineStepFollow, isFalse);
    // 读取预设不得就地补键或覆盖原值。
    expect(legacy.containsKey('asrModel'), isFalse);
    expect(legacy['fontSize'], 60);
    expect(
      ReaderSettings.fromJson({'asrModel': 'some-retired-model'}).asrModel,
      AsrModelChoice.zh14m,
    );
  });

  test('识别模型选择映射到随包模型规格', () {
    expect(AsrModelChoice.bilingualMixed.spec.id, 'zipformer-bilingual-mixed');
    expect(AsrModelChoice.zh14m.spec.id, 'zipformer-zh-14M-int8');
    expect(
      AsrModelChoice.bilingualMixed.spec.assetDir,
      'assets/models/zipformer-bilingual-mixed',
    );
    expect(
      AsrModelChoice.zh14m.spec.assetDir,
      'assets/models/zipformer-zh-14M-int8',
    );
  });

  test('排版派生参数与总行距一致', () {
    const settings = ReaderSettings();
    final size = settings.fontSize;
    final pitch = settings.textStyleHeight * size +
        settings.rowPadYFor(size) * 2 +
        settings.rowGapFor(size);
    expect(pitch, closeTo(settings.lineHeight * size, 1e-6));
  });
}
