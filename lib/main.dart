import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'features/scan/camera_scan_service.dart';
import 'features/scan/scan_configuration.dart';
import 'screens/scan_screen.dart';
import 'services/ai/foundation_models_client.dart';
import 'services/ai/on_device_ai_runner.dart';
import 'services/db/app_database.dart';
import 'services/db/health_record_repository.dart';
import 'services/notifications/daily_reminder_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DatabaseHost());
}

class _DatabaseHost extends StatefulWidget {
  const _DatabaseHost();

  @override
  State<_DatabaseHost> createState() => _DatabaseHostState();
}

class _DatabaseHostState extends State<_DatabaseHost> {
  late final AppDatabase _database = AppDatabase.production();
  late final DriftOnboardingStore _store = DriftOnboardingStore(_database);
  late final HealthRecordRepository _repository = HealthRecordRepository(
    _database,
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

  static ScanSession _createResearchSession() {
    final service = CameraScanService(
      configuration: ScanConfiguration.day1Experimental(),
    );
    return (service: service, preview: service.preview);
  }

  @override
  Widget build(BuildContext context) => MorningCheckApp(
    onboardingStore: _store,
    repository: _repository,
    aiRunner: _aiRunner,
    createScanSession: _createSession,
    createResearchScanSession: _createResearchSession,
    scanModeStore: DriftScanModeStore(_database),
    reminderService: _reminderService,
    reminderStore: _reminderStore,
  );

  @override
  void initState() {
    super.initState();
    // 起動を待たせない。失敗しても通知なしでアプリは使える。
    unawaited(restoreDailyReminder(_reminderStore, _reminderService));
  }

  @override
  void dispose() {
    _aiRunner.dispose();
    unawaited(_database.close());
    super.dispose();
  }
}
