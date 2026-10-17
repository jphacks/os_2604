import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'foundation/scaffold_pages.dart';
import 'navigation/app_routes.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/result_screen.dart';
import 'screens/scan_screen.dart';
import 'services/db/health_record_repository.dart';
import 'services/settings/onboarding_store.dart';
import 'widgets/onboarding_gate.dart';

class MorningCheckApp extends StatelessWidget {
  const MorningCheckApp({
    super.key,
    required this.onboardingStore,
    required this.repository,
    required this.createScanSession,
  });

  final OnboardingStore onboardingStore;
  final HealthRecordRepository repository;

  /// 撮影画面ごとに1回呼ばれる。本番は CameraScanService、テストは偽物を返す。
  final ScanSession Function() createScanSession;

  Widget _home(BuildContext context) => HomeScreen(
    onStartCheck: () => Navigator.of(context).pushNamed(AppRoutes.scan),
    onOpenHistory: () => Navigator.of(context).pushNamed(AppRoutes.history),
    onOpenSettings: () => Navigator.of(context).pushNamed(AppRoutes.settings),
    onShowExplanation: () =>
        Navigator.of(context).pushNamed(AppRoutes.onboarding),
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
        AppRoutes.scan: (_) => ScanScreen(
          repository: repository,
          createSession: createScanSession,
        ),
        AppRoutes.result: (context) {
          final id = ModalRoute.of(context)?.settings.arguments;
          return ResultScreen(
            repository: repository,
            recordId: id is String ? id : null,
            onBackToHome: () =>
                Navigator.of(context)
                    .popUntil(ModalRoute.withName(AppRoutes.home)),
          );
        },
        AppRoutes.history: (_) => const FoundationPlaceholderPage(title: '履歴'),
        AppRoutes.settings: (_) => const FoundationPlaceholderPage(title: '設定'),
      },
    );
  }
}
