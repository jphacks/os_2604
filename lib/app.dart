import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'foundation/scaffold_pages.dart';
import 'navigation/app_routes.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/scan_unavailable_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'services/db/health_record_store.dart';
import 'models/scan_contract.dart';
import 'services/settings/onboarding_store.dart';
import 'widgets/onboarding_gate.dart';

class MorningCheckApp extends StatelessWidget {
  const MorningCheckApp({
    super.key,
    required this.onboardingStore,
    this.recordStore,
    this.scanServiceFactory,
  });

  final OnboardingStore onboardingStore;
  final HealthRecordStore? recordStore;
  final HealthScanService Function()? scanServiceFactory;

  Widget _home(BuildContext context) => HomeScreen(
    onStartCheck: () => Navigator.of(context).pushNamed(AppRoutes.scan),
    onOpenHistory: () => Navigator.of(context).pushNamed(AppRoutes.history),
    onOpenSettings: () => Navigator.of(context).pushNamed(AppRoutes.settings),
    onShowExplanation: () =>
        Navigator.of(context).pushNamed(AppRoutes.onboarding),
    recordStore: recordStore,
  );

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
        AppRoutes.home: (_) =>
            OnboardingGate(store: onboardingStore, homeBuilder: _home),
        AppRoutes.onboarding: (context) =>
            OnboardingScreen(onContinue: () => Navigator.of(context).pop()),
        AppRoutes.scan: (context) => recordStore == null
            ? ScanUnavailableScreen(
                onBackToHome: () => Navigator.of(context).pop(),
              )
            : ScanScreen(
                store: recordStore!,
                serviceFactory: scanServiceFactory,
              ),
        AppRoutes.result: (_) => const FoundationPlaceholderPage(title: '結果'),
        AppRoutes.history: (_) => recordStore == null
            ? const FoundationPlaceholderPage(title: '履歴')
            : HistoryScreen(store: recordStore!),
        AppRoutes.settings: (_) => recordStore == null
            ? const FoundationPlaceholderPage(title: '設定')
            : RecordSettingsScreen(store: recordStore!),
      },
    );
  }
}
