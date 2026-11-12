import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 主题（§19.2 / §19.3 / §19.5）。
///
/// 只使用角色色，壳层禁止直接写 `Color(0x…)`。
abstract final class TpTheme {
  static ThemeData light({Color seed = TpTokens.seed}) =>
      _build(Brightness.light, seed);

  static ThemeData dark({Color seed = TpTokens.seed}) =>
      _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TpTokens.radiusMedium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(TpTokens.touchTarget, TpTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: TpTokens.space4),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(TpTokens.touchTarget, TpTokens.touchTarget),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: TpTokens.space2,
        contentPadding: EdgeInsets.symmetric(
          horizontal: TpTokens.space4,
          vertical: TpTokens.space1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TpTokens.radiusMedium),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    // 用 copyWith 保留排版默认色；直接替换 TextStyle 会让 color 变成 null，
    // 浅色主题下文字会退化成默认灰。
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
