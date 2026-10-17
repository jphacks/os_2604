import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

HealthCheckResult record(String id, DateTime at, {int? selfCondition}) =>
    HealthCheckResult(
      id: id,
      measuredAt: at,
      elapsed: const Duration(seconds: 15, microseconds: 123456),
      faceDetected: true,
      quality: MeasurementQuality.good,
      selfCondition: selfCondition,
    );

void main() {
  late AppDatabase database;
  late HealthRecordRepository repo;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(database);
  });

  tearDown(() async => database.close());

  test('round trip keeps all fields; unmeasured stay null', () async {
    final at = DateTime(2026, 5, 1, 8, 30, 15, 123, 456);
    await repo.insert(record('a', at));
    final found = (await repo.findById('a'))!;
    expect(found.measuredAt, at);
    expect(found.elapsed, const Duration(seconds: 15, microseconds: 123456));
    expect(found.estimatedHeartRateBpm, isNull);
    expect(found.heartRateSource, HeartRateSource.none);
    expect(found.faceColorFeature, isNull);
    expect(found.selfCondition, isNull);
    expect(found.bodyTemperatureC, isNull);
    expect(found.temperatureSource, TemperatureSource.none);
    expect(found.reportText, isNull);
    expect(found.aiMode, isNull);
    expect(await repo.findById('missing'), isNull);
  });

  test('round trip with every field set', () async {
    final full = HealthCheckResult(
      id: 'full',
      measuredAt: DateTime(2026, 5, 1),
      elapsed: const Duration(seconds: 16),
      faceDetected: true,
      quality: MeasurementQuality.good,
      estimatedHeartRateBpm: 72.5,
      heartRateSource: HeartRateSource.rppgExperimental,
      faceColorFeature: 0.25,
      selfCondition: 4,
      bodyTemperatureC: 36.6,
      temperatureSource: TemperatureSource.manual,
      reportText: 'ok',
      aiMode: ReportMode.template,
    );
    await repo.insert(full);
    final f = (await repo.findById('full'))!;
    expect(f.estimatedHeartRateBpm, 72.5);
    expect(f.heartRateSource, HeartRateSource.rppgExperimental);
    expect(f.faceColorFeature, 0.25);
    expect(f.selfCondition, 4);
    expect(f.bodyTemperatureC, 36.6);
    expect(f.temperatureSource, TemperatureSource.manual);
    expect(f.reportText, 'ok');
    expect(f.aiMode, ReportMode.template);
  });

  test('duplicate ID throws and keeps the original', () async {
    await repo.insert(record('a', DateTime(2026, 5, 1), selfCondition: 3));
    await expectLater(
      repo.insert(record('a', DateTime(2026, 5, 2), selfCondition: 5)),
      throwsA(anything),
    );
    final f = (await repo.findById('a'))!;
    expect(f.selfCondition, 3);
    expect(f.measuredAt, DateTime(2026, 5, 1));
  });

  test(
    'appends self condition, temperature and report to the same ID',
    () async {
      await repo.insert(record('a', DateTime(2026, 5, 1)));
      await repo.updateSelfCondition('a', 4);
      await repo.updateTemperature('a', 36.8, TemperatureSource.manual);
      await repo.updateReport('a', 'text', ReportMode.onDevice);
      final f = (await repo.findById('a'))!;
      expect(f.selfCondition, 4);
      expect(f.bodyTemperatureC, 36.8);
      expect(f.temperatureSource, TemperatureSource.manual);
      expect(f.reportText, 'text');
      expect(f.aiMode, ReportMode.onDevice);
      expect(
        await repo.findInRange(DateTime(2026), DateTime(2027)),
        hasLength(1),
      );
    },
  );

  test('update on a missing ID throws', () async {
    await expectLater(repo.updateSelfCondition('x', 3), throwsStateError);
    await expectLater(
      repo.updateTemperature('x', 36, TemperatureSource.manual),
      throwsStateError,
    );
    await expectLater(
      repo.updateReport('x', 't', ReportMode.template),
      throwsStateError,
    );
  });

  test('invalid updates are rejected and the row is unchanged', () async {
    await repo.insert(record('a', DateTime(2026, 5, 1), selfCondition: 2));
    await expectLater(repo.updateSelfCondition('a', 6), throwsArgumentError);
    await expectLater(
      repo.updateTemperature('a', 36, TemperatureSource.none),
      throwsArgumentError,
    );
    await expectLater(
      repo.updateReport('a', '  ', ReportMode.template),
      throwsArgumentError,
    );
    final f = (await repo.findById('a'))!;
    expect(f.selfCondition, 2);
    expect(f.bodyTemperatureC, isNull);
    expect(f.reportText, isNull);
  });

  test('range query is [from, to) ordered newest first', () async {
    await repo.insert(record('d1', DateTime(2026, 5, 1)));
    await repo.insert(record('d3', DateTime(2026, 5, 3)));
    await repo.insert(record('d2', DateTime(2026, 5, 2)));
    await repo.insert(record('d4', DateTime(2026, 5, 4)));
    final ids = (await repo.findInRange(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 4),
    )).map((r) => r.id);
    expect(ids, ['d3', 'd2', 'd1']);
    final obs = await repo.baselineObservations(
      DateTime(2026, 5, 3),
      DateTime(2026, 5, 5),
    );
    expect(obs.map((o) => o.isValid), [true, true]);
    expect((await repo.watchAll().first).map((r) => r.id), [
      'd4',
      'd3',
      'd2',
      'd1',
    ]);
  });

  test('delete removes one; deleteAll keeps onboarding', () async {
    await DriftOnboardingStore(database).completeOnboarding();
    await repo.insert(record('a', DateTime(2026, 5, 1)));
    await repo.insert(record('b', DateTime(2026, 5, 2)));
    await repo.delete('a');
    expect(await repo.findById('a'), isNull);
    expect(await repo.findById('b'), isNotNull);
    await repo.deleteAll();
    expect(await repo.findInRange(DateTime(2000), DateTime(2100)), isEmpty);
    expect(
      await DriftOnboardingStore(database).hasCompletedOnboarding(),
      isTrue,
    );
  });

  test('migration v1 -> v2 preserves onboarding and adds records', () async {
    final v1 = NativeDatabase.memory(
      setup: (db) {
        db.execute(
          'CREATE TABLE onboarding_completions (id INTEGER NOT NULL '
          'CHECK (id = 1), PRIMARY KEY (id))',
        );
        db.execute('INSERT INTO onboarding_completions (id) VALUES (1)');
        db.execute('PRAGMA user_version = 1');
      },
    );
    final migrated = AppDatabase(v1);
    addTearDown(migrated.close);
    expect(
      await DriftOnboardingStore(migrated).hasCompletedOnboarding(),
      isTrue,
    );
    final migratedRepo = HealthRecordRepository(migrated);
    await migratedRepo.insert(record('a', DateTime(2026, 5, 1)));
    expect(await migratedRepo.findById('a'), isNotNull);
  });
}
