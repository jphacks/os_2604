import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'foundation/scaffold_pages.dart';
import 'navigation/app_routes.dart';

class MorningCheckApp extends StatelessWidget {
  const MorningCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '15秒健康チェック',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B63)),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const FoundationHomePage(),
        for (final entry in AppRoutes.destinations.entries)
          entry.key: (_) => FoundationPlaceholderPage(title: entry.value),
      },
    );
  }
}
