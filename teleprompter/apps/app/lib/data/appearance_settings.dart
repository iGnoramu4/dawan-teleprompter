import 'dart:convert';

import 'package:data_store/data_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// 外观设置（M2 主题自定义）：主题模式 + 强调色。
///
/// 存在 `app_settings` 的 `appearance` 键；只影响壳层（列表/编辑/设置），
/// 阅读页仍由台本预设的舞台配色控制。
const String appearanceStorageKey = 'appearance';

class AppearanceSettings {
  const AppearanceSettings({
    this.mode = ThemeMode.system,
    this.accent = TpAccent.indigo,
  });

  final ThemeMode mode;
  final TpAccent accent;

  AppearanceSettings copyWith({ThemeMode? mode, TpAccent? accent}) =>
      AppearanceSettings(
        mode: mode ?? this.mode,
        accent: accent ?? this.accent,
      );

  Map<String, Object?> toJson() => {'mode': mode.name, 'accent': accent.id};

  String toJsonString() => jsonEncode(toJson());

  /// 解析失败回退默认，避免坏数据把启动卡住。
  static AppearanceSettings fromRaw(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const AppearanceSettings();
    final modeName = decoded['mode'];
    final mode = ThemeMode.values.firstWhere(
      (item) => item.name == modeName,
      orElse: () => ThemeMode.system,
    );
    final accentId = decoded['accent'];
    return AppearanceSettings(
      mode: mode,
      accent: TpAccent.fromId(accentId is String ? accentId : null),
    );
  }
}

Future<AppearanceSettings> loadAppearanceSettings(
  ScriptRepository repository,
) async {
  final raw = await repository.getSetting(appearanceStorageKey);
  if (raw == null || raw.isEmpty) return const AppearanceSettings();
  try {
    return AppearanceSettings.fromRaw(raw);
  } catch (_) {
    return const AppearanceSettings();
  }
}

Future<void> saveAppearanceSettings(
  ScriptRepository repository,
  AppearanceSettings settings,
) async {
  await repository.setSetting(appearanceStorageKey, settings.toJsonString());
}
