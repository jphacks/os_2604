import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'navigation/app_routes.dart';
import 'navigation/app_transitions.dart';
import 'screens/history_detail_screen.dart';
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
import 'ui/asakao_style.dart';
import 'widgets/onboarding_gate.dart';
<<<<<<< HEAD
import 'services/device/led_notification_service.dart';
import 'services/device/environment_save_service.dart';
=======
import 'widgets/scan_mode_gate.dart';
import 'services/settings/scan_mode_store.dart';
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834

class MorningCheckApp extends StatelessWidget {
  const MorningCheckApp({
    super.key,
    required this.onboardingStore,
    required this.repository,
    required this.aiRunner,
    required this.createScanSession,
    this.createResearchScanSession,
    this.scanModeStore,
    required this.reminderService,
    required this.reminderStore,
    this.requestCameraPermission = requestSystemCameraPermission,
    this.now = DateTime.now,
    this.ledService,
    this.environmentSaves,
  });

  final OnboardingStore onboardingStore;
  final HealthRecordRepository repository;
  final OnDeviceAiRunner aiRunner;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;
  final LedNotificationService? ledService;
  final EnvironmentSaveService? environmentSaves;

  /// 初回設定でカメラ許可を求める。テストでは偽物に差し替える。
  final Future<bool?> Function() requestCameraPermission;

  /// 本日判定・履歴基準値に使う時計。テストでは固定する。
  final DateTime Function() now;

  /// 撮影画面ごとに1回呼ばれる。本番は CameraScanService、テストは偽物を返す。
  final ScanSession Function() createScanSession;
  final ScanSession Function()? createResearchScanSession;
  final ScanModeStore? scanModeStore;

  Widget _home(BuildContext context) => MainTabsScreen(
    repository: repository,
    ledService: ledService,
    now: now,
    reminderService: reminderService,
    reminderStore: reminderStore,
    scanModeStore: scanModeStore,
    onStartCheck: () => Navigator.of(context).pushNamed(AppRoutes.scan),
  );

  /// 計測の流れ。3-1' は cover で下から出し、4-1 へは fade。結果を閉じると下へ消える。
  /// 5-1 → 5-2 は push。
  Route<void>? _generateRoute(RouteSettings settings) =>
      switch (settings.name) {
        AppRoutes.scan => AppTransitions.cover(
          (_) => ScanModeGate(
            repository: repository,
            standard: createScanSession,
            research: createResearchScanSession,
            store: scanModeStore,
          ),
          settings: settings,
        ),
        AppRoutes.result => AppTransitions.fade(
          (context) {
            final id = settings.arguments;
            return ResultScreen(
              repository: repository,
              aiRunner: aiRunner,
              recordId: id is String ? id : null,
              onBackToHome: () =>
                  Navigator.of(context)
                      .popUntil(ModalRoute.withName(AppRoutes.home)),
            );
          },
          settings: settings,
          dismissDown: true,
        ),
        AppRoutes.historyDetail => AppTransitions.push(
          (_) => HistoryDetailScreen(
            store: repository,
            recordId: switch (settings.arguments) {
              final String id => id,
              _ => null,
            },
          ),
          settings: settings,
        ),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '15秒健康チェック',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: asakaoTheme(),
      initialRoute: AppRoutes.home,
      routes: {
<<<<<<< HEAD
        AppRoutes.home: (_) =>
            OnboardingGate(store: onboardingStore, homeBuilder: _home),
        AppRoutes.onboarding: (context) =>
            OnboardingScreen(onContinue: () => Navigator.of(context).pop()),
        AppRoutes.scan: (_) => ScanScreen(
          repository: repository,
          createSession: createScanSession,
          ledService: ledService,
          environmentSaves: environmentSaves,
        ),
        AppRoutes.result: (context) {
          final id = ModalRoute.of(context)?.settings.arguments;
          return ResultScreen(
            repository: repository,
            aiRunner: aiRunner,
            recordId: id is String ? id : null,
            ledService: ledService,
            environmentSaves: environmentSaves,
            onBackToHome: () =>
                Navigator.of(context)
                    .popUntil(ModalRoute.withName(AppRoutes.home)),
          );
        },
=======
        AppRoutes.home: (_) => OnboardingGate(
          store: onboardingStore,
          homeBuilder: _home,
          reminderService: reminderService,
          reminderStore: reminderStore,
          requestCameraPermission: requestCameraPermission,
        ),
        AppRoutes.onboarding: (context) => OnboardingScreen(
          explanationOnly: true,
          onFinish: () => Navigator.of(context).pop(),
        ),
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834
        AppRoutes.history: (_) => HistoryScreen(store: repository, now: now),
        AppRoutes.settings: (_) => SettingsScreen(
          scanModeStore: scanModeStore,
          repository: repository,
          reminderService: reminderService,
          reminderStore: reminderStore,
          ledService: ledService,
        ),
      },
      onGenerateRoute: _generateRoute,
    );
  }
}
