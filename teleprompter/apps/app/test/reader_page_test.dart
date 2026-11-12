import 'package:core_models/core_models.dart';
import 'package:data_store/data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/providers.dart';
import 'package:teleprompter/features/reader/reader_page.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/reader_settings/reader_settings.dart';

ScriptDocument _document() {
  final now = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch;
  return ScriptDocument(
    id: 's1',
    title: '边距与起始态',
    rawText: '第一行内容用于验证边距与起始态。\n'
        '第二行内容用于验证边距与起始态。\n'
        '第三行内容用于验证边距与起始态。',
    sections: const [],
    markers: const [],
    createdAt: now,
    updatedAt: now,
  );
}

Widget _reader(AppDatabase db, ScriptDocument document) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReaderPage(document: document),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ScriptRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = ScriptRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('左右边距真实作用于渲染画布', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await repo.savePreset(
      'script:s1',
      const ReaderSettings(leftMargin: 0.12, rightMargin: 0.12).toJson(),
    );
    await tester.pumpWidget(_reader(db, _document()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // 逻辑屏宽 400，左右各 12% → 画布 304，左缘 48。
    final stage = find.byKey(const ValueKey('reader-stage'));
    expect(stage, findsOneWidget);
    expect(tester.getSize(stage).width, closeTo(304.0, 0.5));
    expect(tester.getTopLeft(stage).dx, closeTo(48.0, 0.5));
  });

  testWidgets('打开后停在起始态，点击屏幕才开始', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_reader(db, _document()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.textContaining('轻点屏幕开始'), findsOneWidget);

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.textContaining('轻点屏幕开始'), findsNothing);
  });
}
