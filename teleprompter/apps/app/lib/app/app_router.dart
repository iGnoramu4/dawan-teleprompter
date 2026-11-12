import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/import/import_page.dart';
import '../features/reader/reader_page.dart';
import '../features/remote/remote_page.dart';
import '../features/scripts/editor_page.dart';
import '../features/settings/settings_page.dart';
import 'app_routes.dart';

/// 集中装配 feature 页面；feature 层只引用 [AppRoutes] 与参数对象。
Route<dynamic>? appRouteFactory(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const HomePage(),
      );
    case AppRoutes.importPreview:
      final args = settings.arguments;
      if (args is! ImportArgs) return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ImportPage(
          rawText: args.rawText,
          sourceLabel: args.sourceLabel,
          stripMarkdown: args.stripMarkdown,
        ),
      );
    case AppRoutes.editor:
      final args = settings.arguments;
      if (args is! EditorArgs) return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => EditorPage(scriptId: args.scriptId),
      );
    case AppRoutes.reader:
      final args = settings.arguments;
      if (args is! ReaderArgs) return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ReaderPage(
          document: args.document,
          initialAnchor: args.initialAnchor,
          initialAnchorModel: args.initialAnchorModel,
        ),
      );
    case AppRoutes.settings:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SettingsPage(),
      );
    case AppRoutes.remote:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const RemotePage(),
      );
    default:
      return null;
  }
}
