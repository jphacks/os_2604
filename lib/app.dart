import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'navigation/app_routes.dart';
import 'screens/history_screen.dart';
import 'screens/main_tabs_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/result_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ai/on_device_ai_runner.dart';
import 'services/db/health_record_repository.dart';
import 'services/notifications/daily_reminder_service.dart';
import 'services/settings/onboarding_store.dart';
import 'services/settings/reminder_settings_store.dart';
import 'widgets/onboarding_gate.dart';

class MorningCheckApp extends StatelessWidget {
  const MorningCheckApp({
    super.key,
    required this.onboardingStore,
    required this.repository,
    required this.aiRunner,
    required this.createScanSession,
    required this.reminderService,
    required this.reminderStore,
    this.now = DateTime.now,
  });

  final OnboardingStore onboardingStore;
  final HealthRecordRepository repository;
  final OnDeviceAiRunner aiRunner;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;

  /// 本日判定・履歴基準値に使う時計。テストでは固定する。
  final DateTime Function() now;

  /// 撮影画面ごとに1回呼ばれる。本番は CameraScanService、テストは偽物を返す。
  final ScanSession Function() createScanSession;

  Widget _home(BuildContext context) => MainTabsScreen(
    repository: repository,
    now: now,
    reminderService: reminderService,
    reminderStore: reminderStore,
    onStartCheck: () => Navigator.of(context).pushNamed(AppRoutes.scan),
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
            aiRunner: aiRunner,
            recordId: id is String ? id : null,
            onBackToHome: () =>
                Navigator.of(context)
                    .popUntil(ModalRoute.withName(AppRoutes.home)),
          );
        },
        AppRoutes.history: (_) => HistoryScreen(store: repository, now: now),
        AppRoutes.settings: (_) => SettingsScreen(
          repository: repository,
          reminderService: reminderService,
          reminderStore: reminderStore,
        ),
      },
    );
  }
}
