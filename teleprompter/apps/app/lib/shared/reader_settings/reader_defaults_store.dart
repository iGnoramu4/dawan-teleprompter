import 'package:data_store/data_store.dart';

import 'reader_settings.dart';

/// 全局默认阅读参数（M1-c）：存在 `app_settings` 的 `reader_defaults` 键。
///
/// 优先级：台本预设 `script:<id>` > 全局默认 > `ReaderSettings.defaults`。
const String readerDefaultsKey = 'reader_defaults';

Future<ReaderSettings?> loadGlobalReaderDefaults(
  ScriptRepository repository,
) async {
  final raw = await repository.getSetting(readerDefaultsKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    return ReaderSettings.fromRaw(raw);
  } catch (_) {
    return null;
  }
}

Future<void> saveGlobalReaderDefaults(
  ScriptRepository repository,
  ReaderSettings settings,
) async {
  await repository.setSetting(readerDefaultsKey, settings.toJsonString());
}

/// 功能栏手动隐藏状态（全局，不随台本预设变化）。
const String readerPanelHiddenKey = 'reader_panel_hidden';

Future<bool> loadReaderPanelHidden(ScriptRepository repository) async {
  return await repository.getSetting(readerPanelHiddenKey) == '1';
}

Future<void> saveReaderPanelHidden(
  ScriptRepository repository,
  bool hidden,
) async {
  await repository.setSetting(readerPanelHiddenKey, hidden ? '1' : '0');
}
