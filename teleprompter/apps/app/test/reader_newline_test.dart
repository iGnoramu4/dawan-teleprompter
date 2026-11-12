// 回归用例：段落内换行后，换行之后的文字必须照样渲染（P1）。
import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/providers.dart';
import 'package:teleprompter/features/reader/reader_page.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';

const _rawText = '开头内容用于验证段落内换行之前的文字能够正常显示并且足够长以便折行。\n'
    '换行后的文字必须显示出来。\n'
    '\n'
    '第二段内容正常显示。';

const _afterNewline = '换行后的文字必须显示出来';

ScriptDocument _document() {
  final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
  return ScriptDocument(
    id: 's1',
    title: '段内换行',
    rawText: _rawText,
    sections: const [],
    markers: const [],
    createdAt: now,
    updatedAt: now,
  );
}

/// 只取提词正文行（样式字号与阅读设置一致），排除状态栏/角标文字。
List<String> _rowTexts(WidgetTester tester, double fontSize) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .where((text) => text.style?.fontSize == fontSize)
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .toList(growable: false);
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required AppDatabase db,
  required double fontSize,
  required Size logicalSize,
}) async {
  tester.view.physicalSize = logicalSize * 3.0;
  tester.view.devicePixelRatio = 3.0;
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('$fontSize-${logicalSize.width}'),
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReaderPage(document: _document()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(TestWidgetsFlutterBinding
        .instance.platformDispatcher.clearAllTestValues);
  });

  testWidgets('段内换行之后的文字被渲染，且没有行以换行符开头', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    addTearDown(tester.view.reset);

    await _pumpReader(
      tester,
      db: db,
      fontSize: 44,
      logicalSize: const Size(412, 915),
    );

    final rows = _rowTexts(tester, 44);
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.startsWith('\n'), isFalse, reason: '行文本不应以换行符开头：$row');
      expect(row.contains('\n'), isFalse, reason: '行文本不应包含换行：$row');
    }
    expect(rows.join(), contains(_afterNewline));
  });

  testWidgets('多字号 × 多屏宽（含旋转）下换行后的文字都不丢失', (tester) async {
    addTearDown(tester.view.reset);
    const sizes = <Size>[
      Size(360, 800),
      Size(412, 915),
      Size(800, 360),
    ];
    for (final fontSize in <double>[28, 44, 72]) {
      for (final size in sizes) {
        final db = AppDatabase.memory();
        final repo = ScriptRepository(db);
        await repo.savePreset(
          'script:s1',
          ReaderSettings(fontSize: fontSize).toJson(),
        );
        await _pumpReader(
          tester,
          db: db,
          fontSize: fontSize,
          logicalSize: size,
        );

        final rows = _rowTexts(tester, fontSize);
        final label = 'font=$fontSize size=$size';
        expect(rows, isNotEmpty, reason: label);
        for (final row in rows) {
          expect(row.contains('\n'), isFalse, reason: '$label / $row');
        }
        expect(rows.join(), contains(_afterNewline), reason: label);

        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      }
    }
  });
}
