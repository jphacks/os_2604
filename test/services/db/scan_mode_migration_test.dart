import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';

void main() {
  test('v4 adds unknown mode without rewriting dates, P2 values, reports or preferences', () async {
    final directory = await Directory.systemTemp.createTemp('scan-mode-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/synthetic.sqlite');
    final at = DateTime.utc(2026, 10, 17, 8, 30, 1, 2, 3);
    final old = AppDatabase(NativeDatabase(file));
    await DriftOnboardingStore(old).completeOnboarding();
    await DriftReminderSettingsStore(old)
        .save(const ReminderSettings(enabled: true, hour: 7, minute: 15));
    await HealthRecordRepository(old).insert(
      HealthCheckResult(
        id: 'synthetic-legacy',
        measuredAt: at,
        elapsed: const Duration(seconds: 15, microseconds: 123),
        faceDetected: true,
        quality: MeasurementQuality.good,
        estimatedHeartRateBpm: 72,
        heartRateSource: HeartRateSource.rppgExperimental,
        faceColorFeature: 0.4,
        selfCondition: 3,
        bodyTemperatureC: 36.5,
        temperatureSource: TemperatureSource.manual,
        reportText: 'synthetic report',
        aiMode: ReportMode.template,
      ),
    );
    await old.customStatement(
      'ALTER TABLE health_records DROP COLUMN scan_mode',
    );
    await old.customStatement('PRAGMA user_version = 4');
    await old.close();
    for (var opening = 0; opening < 2; opening++) {
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        final repo = HealthRecordRepository(migrated);
        final r = (await repo.findById('synthetic-legacy'))!;
        expect(r.scanMode, ScanMode.legacyUnknown);
        expect(r.measuredAt.toUtc(), at);
        expect(r.elapsed, const Duration(seconds: 15, microseconds: 123));
        expect(r.estimatedHeartRateBpm, 72);
        expect(r.heartRateSource, HeartRateSource.rppgExperimental);
        expect(r.faceColorFeature, 0.4);
        expect(r.selfCondition, 3);
        expect(r.bodyTemperatureC, 36.5);
        expect(r.temperatureSource, TemperatureSource.manual);
        expect(r.reportText, 'synthetic report');
        expect(r.aiMode, ReportMode.template);
        expect(
          await DriftOnboardingStore(migrated).hasCompletedOnboarding(),
          isTrue,
        );
        final reminder = await DriftReminderSettingsStore(migrated).load();
        expect(
          (reminder.enabled, reminder.hour, reminder.minute),
          (true, 7, 15),
        );
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          6,
        );
        if (opening == 0) {
          await repo.insert(
            HealthCheckResult(
              id: 'research-null',
              measuredAt: at,
              elapsed: const Duration(seconds: 15),
              faceDetected: true,
              quality: MeasurementQuality.good,
              scanMode: ScanMode.research,
            ),
          );
          await repo.updateSelfCondition('research-null', 4);
          await repo.updateReport(
            'research-null',
            'synthetic new report',
            ReportMode.template,
          );
        } else {
          final added = (await repo.findById('research-null'))!;
          expect(added.scanMode, ScanMode.research);
          expect(added.estimatedHeartRateBpm, isNull);
          expect(added.selfCondition, 4);
          expect(added.reportText, 'synthetic new report');
        }
      } finally {
        await migrated.close();
      }
    }
  });

  test(
    'standard mode rejects experimental values instead of relabeling them',
    () {
      expect(
        () => HealthCheckResult(
          id: 'synthetic-invalid',
          measuredAt: DateTime(2026),
          elapsed: const Duration(seconds: 15),
          faceDetected: true,
          quality: MeasurementQuality.good,
          scanMode: ScanMode.standard,
          estimatedHeartRateBpm: 72,
          heartRateSource: HeartRateSource.rppgExperimental,
        ),
        throwsArgumentError,
      );
    },
  );
}
