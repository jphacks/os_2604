import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'features/scan/camera_scan_service.dart';
import 'screens/scan_screen.dart';
import 'services/db/app_database.dart';
import 'services/db/health_record_repository.dart';

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

  static ScanSession _createSession() {
    final service = CameraScanService();
    return (service: service, preview: service.preview);
  }

  @override
  Widget build(BuildContext context) => MorningCheckApp(
    onboardingStore: _store,
    repository: _repository,
    createScanSession: _createSession,
  );

  @override
  void dispose() {
    unawaited(_database.close());
    super.dispose();
  }
}
