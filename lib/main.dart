import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'features/scan/camera_scan_service.dart';
import 'screens/scan_screen.dart';
import 'services/ai/foundation_models_client.dart';
import 'services/ai/on_device_ai_runner.dart';
import 'services/db/app_database.dart';
import 'services/db/health_record_repository.dart';
import 'services/notifications/daily_reminder_service.dart';
import 'services/device/led_notification_service.dart';
import 'services/device/reactive_led_transport.dart';
import 'services/db/environment_record_repository.dart';
import 'services/device/environment_save_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DatabaseHost());
}

class _DatabaseHost extends StatefulWidget {
  const _DatabaseHost();

  @override
  State<_DatabaseHost> createState() => _DatabaseHostState();
}

class _DatabaseHostState extends State<_DatabaseHost>
    with WidgetsBindingObserver {
  late final LedNotificationService? _ledService =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? LedNotificationService(ReactiveLedTransport())
      : null;
  late final AppDatabase _database = AppDatabase.production();
  late final DriftOnboardingStore _store = DriftOnboardingStore(_database);
  late final HealthRecordRepository _repository = HealthRecordRepository(
    _database,
  );

  late final EnvironmentSaveService _environmentSaves = EnvironmentSaveService(
    EnvironmentRecordRepository(_database),
  );

  late final DriftReminderSettingsStore _reminderStore =
      DriftReminderSettingsStore(_database);
  final LocalDailyReminderService _reminderService =
      LocalDailyReminderService();

  final OnDeviceAiRunner _aiRunner = OnDeviceAiRunner(
    client: const FoundationModelsClient(),
    timeout: const Duration(seconds: 10),
  );

  static ScanSession _createSession() {
    final service = CameraScanService();
    return (service: service, preview: service.preview);
  }

  @override
  Widget build(BuildContext context) => MorningCheckApp(
    onboardingStore: _store,
    repository: _repository,
    aiRunner: _aiRunner,
    createScanSession: _createSession,
    reminderService: _reminderService,
    reminderStore: _reminderStore,
    ledService: _ledService,
    environmentSaves: _environmentSaves,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 起動を待たせない。失敗しても通知なしでアプリは使える。
    unawaited(restoreDailyReminder(_reminderStore, _reminderService));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ledService?.dispose();
    _environmentSaves.dispose();
    _aiRunner.dispose();
    unawaited(_database.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ledService?.setForeground(
      state == AppLifecycleState.resumed,
      interrupt: state != AppLifecycleState.inactive,
    );
  }
}
