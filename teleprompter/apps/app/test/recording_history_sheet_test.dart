import 'package:data_store/data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/l10n/generated/app_localizations.dart';
import 'package:teleprompter/shared/recording/recording_history_sheet.dart';

RecordingEntry _entry(String id, {int durationMs = 60000}) => RecordingEntry(
      id: id,
      scriptId: 's1',
      path: '/tmp/$id.wav',
      durationMs: durationMs,
      createdAt: 1762345678000,
      sizeBytes: 2 * 1024 * 1024,
    );

Widget _host({
  required List<RecordingEntry> entries,
  required void Function(RecordingEntry) onReplay,
  required Future<void> Function(RecordingEntry) onExport,
  required Future<List<RecordingEntry>> Function(RecordingEntry) onDelete,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showRecordingHistorySheet(
              context: context,
              entries: entries,
              onReplay: onReplay,
              onExport: onExport,
              onDelete: onDelete,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('展示录制列表与时长/大小', (tester) async {
    final replayed = <RecordingEntry>[];
    await tester.pumpWidget(
      _host(
        entries: [_entry('a', durationMs: 65000), _entry('b')],
        onReplay: replayed.add,
        onExport: (_) async {},
        onDelete: (_) async => const [],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('录制历史'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-b')), findsOneWidget);
    expect(find.text('时长 01:05'), findsOneWidget);
    expect(find.textContaining('2.0 MB'), findsNWidgets(2));
  });

  testWidgets('点按条目复盘并关闭面板', (tester) async {
    final replayed = <RecordingEntry>[];
    final entry = _entry('a');
    await tester.pumpWidget(
      _host(
        entries: [entry],
        onReplay: replayed.add,
        onExport: (_) async {},
        onDelete: (_) async => const [],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('时长 01:00'));
    await tester.pumpAndSettle();
    expect(replayed.single.id, 'a');
    expect(find.text('录制历史'), findsNothing);
  });

  testWidgets('导出按钮触发回调且面板保持', (tester) async {
    RecordingEntry? exported;
    final entry = _entry('a');
    await tester.pumpWidget(
      _host(
        entries: [entry],
        onReplay: (_) {},
        onExport: (value) async => exported = value,
        onDelete: (_) async => const [],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导出'));
    await tester.pumpAndSettle();
    expect(exported?.id, 'a');
    expect(find.text('录制历史'), findsOneWidget);
  });

  testWidgets('删除需确认，确认后刷新为空态', (tester) async {
    final deleted = <String>[];
    final entry = _entry('a');
    await tester.pumpWidget(
      _host(
        entries: [entry],
        onReplay: (_) {},
        onExport: (_) async {},
        onDelete: (value) async {
          deleted.add(value.id);
          return const [];
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条录音？音频文件将一并删除。'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deleted, ['a']);
    expect(find.text('暂无录音'), findsOneWidget);
  });

  testWidgets('空列表显示占位文案', (tester) async {
    await tester.pumpWidget(
      _host(
        entries: const [],
        onReplay: (_) {},
        onExport: (_) async {},
        onDelete: (_) async => const [],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('暂无录音'), findsOneWidget);
  });
}
