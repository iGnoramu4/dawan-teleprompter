import 'package:data_store/data_store.dart';

/// 提词页功能栏可配置按钮（全局默认，不随台本预设变化）。
///
/// 返回、设置、隐藏三个入口始终显示，不在此列表中。
enum ReaderBarAction {
  prev,
  next,
  playPause,
  speed,
  fontSize,
  mic,
  restart,
  overlay,
  remote,
  display,
  record,
  history,
  lock,
}

/// 默认只保留最常用的跟随控制，避免开箱即是一块参数面板。
const List<ReaderBarAction> defaultReaderBarActions = [
  ReaderBarAction.prev,
  ReaderBarAction.playPause,
  ReaderBarAction.next,
  ReaderBarAction.mic,
];

const String readerBarActionsKey = 'reader_bar_actions';

Future<List<ReaderBarAction>> loadReaderBarActions(
  ScriptRepository repository,
) async {
  final raw = await repository.getSetting(readerBarActionsKey);
  if (raw == null) return defaultReaderBarActions;
  if (raw.trim().isEmpty) return const [];
  final saved = <ReaderBarAction>{};
  for (final name in raw.split(',')) {
    for (final action in ReaderBarAction.values) {
      if (action.name == name.trim()) saved.add(action);
    }
  }
  // 按枚举顺序归一化，保证功能栏排列稳定。
  return [
    for (final action in ReaderBarAction.values)
      if (saved.contains(action)) action,
  ];
}

Future<void> saveReaderBarActions(
  ScriptRepository repository,
  List<ReaderBarAction> actions,
) async {
  final ordered = <ReaderBarAction>{...actions};
  await repository.setSetting(
    readerBarActionsKey,
    [
      for (final action in ReaderBarAction.values)
        if (ordered.contains(action)) action.name,
    ].join(','),
  );
}
