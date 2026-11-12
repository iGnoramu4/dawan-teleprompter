import 'package:data_store/data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/appearance_settings.dart';
import 'package:teleprompter/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('databaseProvider 未覆盖时抛出明确的初始化错误', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(databaseProvider),
      throwsA(isA<StateError>()),
    );
  });

  test('默认状态值', () {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    expect(container.read(appearanceProvider), const AppearanceSettings());
    expect(container.read(scriptQueryProvider), '');
    expect(container.read(scriptSortProvider), ScriptSort.updatedDesc);
    expect(container.read(scriptViewProvider), ScriptView.active);
    expect(container.read(scriptRepositoryProvider).db, db);
  });

  test('列表 Provider 响应搜索、排序与视图切换', () async {
    final repository = ScriptRepository(db);
    final short = await repository.createScript(title: '短稿', text: '短内容');
    final long = await repository.createScript(
      title: '长稿',
      text: List.filled(12, '这是一段较长的正文用于排序。').join('\n'),
    );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      scriptSummariesProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    var list = await container.read(scriptSummariesProvider.future);
    expect(list, hasLength(2));

    container.read(scriptQueryProvider.notifier).state = '短稿';
    list = await container.read(scriptSummariesProvider.future);
    expect(list, hasLength(1));
    expect(list.single.title, '短稿');

    container.read(scriptQueryProvider.notifier).state = '';
    container.read(scriptSortProvider.notifier).state = ScriptSort.titleAsc;
    list = await container.read(scriptSummariesProvider.future);
    expect(list.map((item) => item.title), ['长稿', '短稿'].toList()..sort());

    await repository.setFavorite(short.id, true);
    container.read(scriptViewProvider.notifier).state = ScriptView.favorite;
    list = await container.read(scriptSummariesProvider.future);
    expect(list.single.id, short.id);

    container.read(scriptViewProvider.notifier).state = ScriptView.active;
    list = await container.read(scriptSummariesProvider.future);
    expect(list.map((item) => item.id), containsAll([short.id, long.id]));
  });
}
