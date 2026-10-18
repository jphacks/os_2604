import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/analysis/history_baseline.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';

void main() {
  late Directory directory;
  late File file;
  final at = DateTime.utc(2026, 10, 14, 1);
  final precise = at.add(const Duration(days: 1, microseconds: 123456));
  final last = at.add(const Duration(days: 2));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy_timestamp_');
    file = File('${directory.path}/synthetic.sqlite');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<void> seed(int version, {bool rejectUpdate = false}) async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      await DriftOnboardingStore(db).completeOnboarding();
      await DriftReminderSettingsStore(db)
          .save(const ReminderSettings(enabled: true, hour: 6, minute: 45));
      final repo = HealthRecordRepository(db);
      for (final entry in {
        'legacy': at,
        'precise': precise,
        'last': last,
      }.entries) {
        await repo.insert(
          HealthCheckResult(
            id: entry.key,
            measuredAt: entry.value,
            elapsed: const Duration(seconds: 15, microseconds: 123),
            faceDetected: true,
            quality: MeasurementQuality.good,
            selfCondition: entry.key == 'legacy' ? 2 : 4,
            bodyTemperatureC: entry.key == 'legacy' ? 36.5 : null,
            temperatureSource: entry.key == 'legacy'
                ? TemperatureSource.manual
                : TemperatureSource.none,
            reportText: entry.key == 'legacy' ? 'synthetic template' : null,
            aiMode: entry.key == 'legacy' ? ReportMode.template : null,
          ),
        );
      }
      // Reconstruct the deployed v2/v3 data representation, which has the same
      // health table shape but stores seconds for the old integration build.
      await db.customStatement(
        'UPDATE health_records SET measured_at = ? WHERE id = ?',
        [at.millisecondsSinceEpoch ~/ 1000, 'legacy'],
      );
      await db.customStatement('DROP TABLE health_record_environment');
      await db.customStatement('DROP TABLE scan_preferences');
      if (version == 2) {
        await db.customStatement('DROP TABLE reminder_preferences');
      }
      if (rejectUpdate) {
        await db.customStatement(
          'CREATE TRIGGER reject_migration BEFORE UPDATE ON health_records '
          "BEGIN SELECT RAISE(ABORT, 'synthetic migration failure'); END",
        );
      }
      await db.customStatement(
        'ALTER TABLE health_records DROP COLUMN scan_mode',
      );
      await db.customStatement('PRAGMA user_version = $version');
    } finally {
      await db.close();
    }
  }

  for (final version in [2, 3]) {
    test(
      'v$version keeps mixed units, all fields and settings after reopen',
      () async {
        await seed(version);
        for (var opening = 0; opening < 2; opening++) {
          final db = AppDatabase(NativeDatabase(file));
          try {
            final repo = HealthRecordRepository(db);
            final records = await repo.loadAll();
            expect(records.map((r) => r.id), ['last', 'precise', 'legacy']);
            expect(records.map((r) => r.measuredAt.toUtc()), [
              last,
              precise,
              at,
            ]);
            final legacy = records.last;
            expect(
              legacy.elapsed,
              const Duration(seconds: 15, microseconds: 123),
            );
            expect(legacy.faceDetected, isTrue);
            expect(legacy.quality, MeasurementQuality.good);
            expect(legacy.selfCondition, 2);
            expect(legacy.bodyTemperatureC, 36.5);
            expect(legacy.temperatureSource, TemperatureSource.manual);
            expect(legacy.reportText, 'synthetic template');
            expect(legacy.aiMode, ReportMode.template);
            for (final r in records) {
              expect(r.estimatedHeartRateBpm, isNull);
              expect(r.heartRateSource, HeartRateSource.none);
              expect(r.faceColorFeature, isNull);
            }
            expect(records.first.bodyTemperatureC, isNull);
            expect(records.first.temperatureSource, TemperatureSource.none);
            expect(records.first.reportText, isNull);
            expect(records.first.aiMode, isNull);
            expect(
              await DriftOnboardingStore(db).hasCompletedOnboarding(),
              isTrue,
            );
            final reminder = await DriftReminderSettingsStore(db).load();
            expect((
              reminder.enabled,
              reminder.hour,
              reminder.minute,
            ), version == 3 ? (true, 6, 45) : (false, 8, 0));
            expect((await repo.findInRange(at, last)).map((r) => r.id), [
              'precise',
              'legacy',
            ]);
            final baseline = calculateHistoryBaseline(
              await repo.baselineObservations(
                at,
                last.add(const Duration(days: 1)),
              ),
              referenceDate: DateTime(2026, 10, 17),
            );
            expect(baseline.validRecordCount, 3);
            expect(baseline.selfConditionMedian, 4);
            expect(
              (await db.customSelect('PRAGMA user_version').getSingle())
                  .read<int>('user_version'),
              9,
            );
          } finally {
            await db.close();
          }
        }
      },
    );
  }

  test('only UTC 2026 seconds are converted, including year boundaries', () async {
    final db = AppDatabase(NativeDatabase(file));
    final rawValues = [
      DateTime.utc(2026).millisecondsSinceEpoch ~/ 1000 - 1,
      DateTime.utc(2026).millisecondsSinceEpoch ~/ 1000,
      DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000 - 1,
      DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
      precise.microsecondsSinceEpoch,
      0,
      -1,
    ];
    try {
      final repo = HealthRecordRepository(db);
      for (var i = 0; i < rawValues.length; i++) {
        await repo.insert(
          HealthCheckResult(
            id: 'boundary-$i',
            measuredAt: at,
            elapsed: const Duration(seconds: 15),
            faceDetected: true,
            quality: MeasurementQuality.good,
          ),
        );
        await db.customStatement(
          'UPDATE health_records SET measured_at = ? WHERE id = ?',
          [rawValues[i], 'boundary-$i'],
        );
      }
      await db.customStatement('DROP TABLE health_record_environment');
      await db.customStatement('DROP TABLE scan_preferences');
      await db.customStatement('PRAGMA user_version = 3');
    } finally {
      await db.close();
    }
    final migrated = AppDatabase(NativeDatabase(file));
    try {
      for (var i = 0; i < rawValues.length; i++) {
        final row = await migrated
            .customSelect(
              "SELECT measured_at FROM health_records WHERE id = 'boundary-$i'",
            )
            .getSingle();
        expect(
          row.read<int>('measured_at'),
          (i == 1 || i == 2) ? rawValues[i] * 1000000 : rawValues[i],
        );
      }
    } finally {
      await migrated.close();
    }
  });

  test('migration failure rolls back and retry preserves old data', () async {
    await seed(2, rejectUpdate: true);
    final failing = AppDatabase(NativeDatabase(file));
    try {
      await expectLater(
        HealthRecordRepository(failing).loadAll(),
        throwsException,
      );
    } finally {
      await failing.close();
    }
    var checked = false;
    final recovered = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          expect(raw.select('PRAGMA user_version').single['user_version'], 2);
          expect(
            raw
                .select(
                  "SELECT measured_at FROM health_records WHERE id = 'legacy'",
                )
                .single['measured_at'],
            at.millisecondsSinceEpoch ~/ 1000,
          );
          expect(raw.select('SELECT * FROM health_records'), hasLength(3));
          expect(
            raw.select(
              "SELECT name FROM sqlite_master WHERE name = 'reminder_preferences'",
            ),
            isEmpty,
          );
          raw.execute('DROP TRIGGER reject_migration');
          checked = true;
        },
      ),
    );
    try {
      expect(
        (await HealthRecordRepository(recovered).findById('legacy'))!.measuredAt
            .toUtc(),
        at,
      );
      expect(checked, isTrue);
      expect(
        await DriftOnboardingStore(recovered).hasCompletedOnboarding(),
        isTrue,
      );
    } finally {
      await recovered.close();
    }
  });
}
