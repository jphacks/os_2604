import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('startup-migration-');
    file = File('${directory.path}/synthetic.sqlite');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<List<Map<String, Object?>>> seed({String? columnDefinition}) async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      await DriftOnboardingStore(db).completeOnboarding();
      await DriftReminderSettingsStore(db)
          .save(const ReminderSettings(enabled: true, hour: 6, minute: 45));
      final repo = HealthRecordRepository(db);
      for (final mode in ScanMode.values) {
        await repo.insert(
          HealthCheckResult(
            id: 'synthetic-${mode.name}',
            measuredAt: DateTime.utc(2026, 10, 18, 1, 2, 3, 4, 5),
            elapsed: const Duration(seconds: 15, microseconds: 123),
            faceDetected: true,
            quality: MeasurementQuality.good,
            scanMode: mode,
            estimatedHeartRateBpm: mode == ScanMode.research ? 72 : null,
            heartRateSource: mode == ScanMode.research
                ? HeartRateSource.rppgExperimental
                : HeartRateSource.none,
            faceColorFeature: mode == ScanMode.research ? 0.4 : null,
            selfCondition: 3,
            bodyTemperatureC: 36.5,
            temperatureSource: TemperatureSource.manual,
            reportText: 'synthetic report',
            aiMode: ReportMode.template,
          ),
        );
      }
      if (columnDefinition != null) {
        await db.customStatement(
          'ALTER TABLE health_records DROP COLUMN scan_mode',
        );
        await db.customStatement(
          'ALTER TABLE health_records ADD COLUMN scan_mode $columnDefinition',
        );
      }
      // Reproduce the device: the column already exists, but the version is
      // still 4 and the v6 preferences table has not been created.
      await db.customStatement('DROP TABLE scan_preferences');
      await db.customStatement('DROP TABLE health_record_environment');
      await db.customStatement('PRAGMA user_version = 4');
      return (await db
              .customSelect('SELECT * FROM health_records ORDER BY id')
              .get())
          .map((row) => row.data)
          .toList();
    } finally {
      await db.close();
    }
  }

  test('v4 with existing scan_mode opens settings and preserves all records after restart', () async {
    final before = await seed();
    for (var opening = 0; opening < 2; opening++) {
      final db = AppDatabase(NativeDatabase(file));
      try {
        expect(await DriftOnboardingStore(db).hasCompletedOnboarding(), isTrue);
        final reminder = await DriftReminderSettingsStore(db).load();
        expect(
          (reminder.enabled, reminder.hour, reminder.minute),
          (true, 6, 45),
        );
        expect(
          (await db
                  .customSelect('SELECT * FROM health_records ORDER BY id')
                  .get())
              .map((row) => row.data),
          before,
        );
        final records = await HealthRecordRepository(db).loadAll();
        expect(
          records.map((record) => record.scanMode),
          unorderedEquals(ScanMode.values),
        );
        final modeStore = DriftScanModeStore(db);
        expect(await modeStore.loadResearchMode(), opening > 0);
        if (opening == 0) await modeStore.saveResearchMode(true);
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          7,
        );
      } finally {
        await db.close();
      }
    }
  });

  for (final definition in [
    'INTEGER NOT NULL DEFAULT 0',
    "TEXT DEFAULT 'legacyUnknown'",
    "TEXT NOT NULL DEFAULT 'standard'",
  ]) {
    test(
      'incompatible existing column rolls back without changing records: $definition',
      () async {
        final before = await seed(columnDefinition: definition);
        for (var opening = 0; opening < 2; opening++) {
          var inspected = false;
          final db = AppDatabase(
            NativeDatabase(
              file,
              setup: (raw) {
                expect(
                  raw.select('PRAGMA user_version').single['user_version'],
                  4,
                );
                expect(
                  raw
                      .select('SELECT * FROM health_records ORDER BY id')
                      .map((row) => Map<String, Object?>.from(row)),
                  before,
                );
                expect(
                  raw.select(
                    "SELECT name FROM sqlite_master WHERE name = 'scan_preferences'",
                  ),
                  isEmpty,
                );
                inspected = true;
              },
            ),
          );
          try {
            await expectLater(
              DriftOnboardingStore(db).hasCompletedOnboarding(),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  contains('Unexpected health_records.scan_mode schema'),
                ),
              ),
            );
            expect(inspected, isTrue);
          } finally {
            await db.close();
          }
        }
      },
    );
  }
}
