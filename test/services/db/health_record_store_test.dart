import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';

HealthCheckResult record({
  int? condition,
  double? temperature,
  String? report,
}) => HealthCheckResult(
  id: 'synthetic-record',
  measuredAt: DateTime.utc(2026, 10, 17, 1),
  elapsed: const Duration(seconds: 15, microseconds: 123),
  faceDetected: true,
  quality: MeasurementQuality.good,
  selfCondition: condition,
  bodyTemperatureC: temperature,
  temperatureSource: temperature == null
      ? TemperatureSource.none
      : TemperatureSource.manual,
  reportText: report,
  aiMode: report == null ? null : ReportMode.template,
);

void main() {
  late AppDatabase db;
  late DriftHealthRecordStore store;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftHealthRecordStore(db);
  });
  tearDown(() => db.close());

  test(
    'successful measurement round trips with nulls, ID and exact duration',
    () async {
      await store.insert(record());
      final saved = (await store.loadAll()).single;
      expect(saved.id, 'synthetic-record');
      expect(saved.measuredAt.toUtc(), DateTime.utc(2026, 10, 17, 1));
      expect(saved.elapsed, const Duration(seconds: 15, microseconds: 123));
      expect(saved.bodyTemperatureC, isNull);
      expect(saved.estimatedHeartRateBpm, isNull);
      expect(saved.reportText, isNull);
      expect(saved.aiMode, isNull);
    },
  );

  test('duplicate insertion cannot overwrite a measurement', () async {
    await store.insert(record());
    await expectLater(store.insert(record(condition: 4)), throwsException);
    expect((await store.loadAll()).single.selfCondition, isNull);
  });

  test(
    'inputs and report update atomically without changing measurement',
    () async {
      await store.insert(record());
      expect(
        await store.updateInputsAndReport(
          record(condition: 3, temperature: 36.5, report: 'synthetic template'),
        ),
        isTrue,
      );
      final saved = (await store.loadAll()).single;
      expect(saved.selfCondition, 3);
      expect(saved.bodyTemperatureC, 36.5);
      expect(saved.temperatureSource, TemperatureSource.manual);
      expect(saved.aiMode, ReportMode.template);
      expect(saved.reportText, 'synthetic template');
      expect(saved.elapsed, record().elapsed);
      expect(await store.updateInputsAndReport(record()), isTrue);
      expect((await store.loadAll()).single.bodyTemperatureC, isNull);
    },
  );

  test(
    'late update after individual or all deletion does not resurrect a row',
    () async {
      await store.insert(record());
      await store.deleteOne(record().id);
      expect(await store.updateInputsAndReport(record(condition: 4)), isFalse);
      await store.insert(record());
      await store.deleteAll();
      expect(await store.updateInputsAndReport(record(condition: 4)), isFalse);
      expect(await store.loadAll(), isEmpty);
    },
  );

  test('failed write propagates and leaves no successful record', () async {
    await store.loadAll();
    await db.customStatement(
      "CREATE TRIGGER reject_record BEFORE INSERT ON health_records BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
    );
    await expectLater(store.insert(record()), throwsException);
    expect(await store.loadAll(), isEmpty);
  });

  test('invalid measurement is never inserted', () async {
    final invalid = HealthCheckResult(
      id: 'failed',
      measuredAt: DateTime.utc(2026),
      elapsed: Duration.zero,
      faceDetected: false,
      quality: MeasurementQuality.interrupted,
    );
    await expectLater(store.insert(invalid), throwsArgumentError);
    expect(await store.loadAll(), isEmpty);
  });

  test(
    'v1 migration preserves onboarding and measurements persist after reopen',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'health_migration_',
      );
      final file = File('${directory.path}/test.sqlite');
      AppDatabase? opened;
      try {
        final old = AppDatabase(NativeDatabase(file));
        await DriftOnboardingStore(old).completeOnboarding();
        // Reconstruct B's v1 schema: only the onboarding table and version 1.
        await old.customStatement('DROP TABLE health_records');
        await old.customStatement('PRAGMA user_version = 1');
        await old.close();
        opened = AppDatabase(NativeDatabase(file));
        expect(
          await DriftOnboardingStore(opened).hasCompletedOnboarding(),
          isTrue,
        );
        await DriftHealthRecordStore(opened).insert(record());
        await opened.close();
        opened = AppDatabase(NativeDatabase(file));
        expect(
          (await DriftHealthRecordStore(opened).loadAll()).single.id,
          record().id,
        );
        expect(
          await DriftOnboardingStore(opened).hasCompletedOnboarding(),
          isTrue,
        );
      } finally {
        await opened?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
