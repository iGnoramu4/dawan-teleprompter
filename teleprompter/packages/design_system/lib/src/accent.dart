import 'package:flutter/material.dart';

import 'tokens.dart';

/// 应用强调色（M2 主题自定义）。
///
/// 只提供少量预设，避免任意取色导致对比度不可控；实际配色由
/// `ColorScheme.fromSeed` 生成，深浅色角色由 Material 3 补齐。
enum TpAccent {
  indigo('indigo', TpTokens.seed),
  teal('teal', Color(0xFF00695C)),
  amber('amber', Color(0xFF9A6200)),
  rose('rose', Color(0xFFB3365A));

  const TpAccent(this.id, this.seed);

  /// 持久化用的稳定标识，不要改。
  final String id;
  final Color seed;

  static TpAccent fromId(String? id) {
    for (final accent in values) {
      if (accent.id == id) return accent;
    }
    return TpAccent.indigo;
  }
}
