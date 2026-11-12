import 'package:data_store/data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance_settings.dart';

/// 由 `main()` 在启动时覆盖为已打开的数据库。
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('Database not initialized'),
);

/// 由 `main()` 在启动时覆盖为从数据库读出的外观设置。
final appearanceProvider = StateProvider<AppearanceSettings>(
  (ref) => const AppearanceSettings(),
);

final scriptRepositoryProvider = Provider<ScriptRepository>(
  (ref) => ScriptRepository(ref.watch(databaseProvider)),
);

/// 台本列表搜索词。
final scriptQueryProvider = StateProvider<String>((ref) => '');

/// 台本列表排序。
final scriptSortProvider = StateProvider<ScriptSort>(
  (ref) => ScriptSort.updatedDesc,
);

/// 台本列表视图（全部/收藏/归档/回收站）。
final scriptViewProvider = StateProvider<ScriptView>(
  (ref) => ScriptView.active,
);

final scriptSummariesProvider = StreamProvider<List<ScriptSummary>>((ref) {
  final repository = ref.watch(scriptRepositoryProvider);
  return repository.watchSummaries(
    query: ref.watch(scriptQueryProvider),
    sort: ref.watch(scriptSortProvider),
    view: ref.watch(scriptViewProvider),
  );
});
