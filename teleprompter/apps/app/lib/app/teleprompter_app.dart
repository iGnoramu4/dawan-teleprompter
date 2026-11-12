import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_router.dart';
import 'app_routes.dart';

class TeleprompterApp extends ConsumerWidget {
  const TeleprompterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: TpTheme.light(seed: appearance.accent.seed),
      darkTheme: TpTheme.dark(seed: appearance.accent.seed),
      themeMode: appearance.mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.home,
      onGenerateRoute: appRouteFactory,
    );
  }
}
