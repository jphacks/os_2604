import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/health_check_result.dart';
import '../settings/onboarding_store.dart';
import 'health_record_store.dart';

part 'app_database.g.dart';

/// A singleton row exists only after the introductory explanation is completed.
class OnboardingCompletions extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The application owns this connection and must await [close] on disposal.
@DataClassName('StoredHealthRecord')
class HealthRecords extends Table {
  TextColumn get id => text()();
  DateTimeColumn get measuredAt => dateTime()();
  IntColumn get elapsedMicros => integer()();
  BoolColumn get faceDetected => boolean()();
  TextColumn get quality => text()();
  RealColumn get estimatedHeartRateBpm => real().nullable()();
  TextColumn get heartRateSource => text()();
  RealColumn get faceColorFeature => real().nullable()();
  IntColumn get selfCondition => integer().nullable()();
  RealColumn get bodyTemperatureC => real().nullable()();
  TextColumn get temperatureSource => text()();
  TextColumn get reportText => text().nullable()();
  TextColumn get aiMode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [OnboardingCompletions, HealthRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'os_2604'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(healthRecords);
    },
  );
}

class DriftHealthRecordStore implements HealthRecordStore {
  DriftHealthRecordStore(this._database);
  final AppDatabase _database;

  @override
  Future<void> insert(HealthCheckResult result) async {
    if (result.quality != MeasurementQuality.good) {
      throw ArgumentError('Only successful measurements can be saved.');
    }
    await _database
        .into(_database.healthRecords)
        .insert(
          HealthRecordsCompanion.insert(
            id: result.id,
            measuredAt: result.measuredAt.toUtc(),
            elapsedMicros: result.elapsed.inMicroseconds,
            faceDetected: result.faceDetected,
            quality: result.quality.name,
            estimatedHeartRateBpm: Value(result.estimatedHeartRateBpm),
            heartRateSource: result.heartRateSource.name,
            faceColorFeature: Value(result.faceColorFeature),
            selfCondition: Value(result.selfCondition),
            bodyTemperatureC: Value(result.bodyTemperatureC),
            temperatureSource: result.temperatureSource.name,
            reportText: Value(result.reportText),
            aiMode: Value(result.aiMode?.name),
          ),
        );
  }

  @override
  Future<bool> updateInputsAndReport(HealthCheckResult result) async {
    final count =
        await (_database.update(
          _database.healthRecords,
        )..where((row) => row.id.equals(result.id))).write(
          HealthRecordsCompanion(
            selfCondition: Value(result.selfCondition),
            bodyTemperatureC: Value(result.bodyTemperatureC),
            temperatureSource: Value(result.temperatureSource.name),
            reportText: Value(result.reportText),
            aiMode: Value(result.aiMode?.name),
          ),
        );
    return count == 1;
  }

  SimpleSelectStatement<$HealthRecordsTable, StoredHealthRecord> _query() =>
      _database.select(_database.healthRecords)
        ..orderBy([(row) => OrderingTerm.desc(row.measuredAt)]);

  HealthCheckResult _decode(StoredHealthRecord row) => HealthCheckResult(
    id: row.id,
    measuredAt: row.measuredAt.toLocal(),
    elapsed: Duration(microseconds: row.elapsedMicros),
    faceDetected: row.faceDetected,
    quality: MeasurementQuality.values.byName(row.quality),
    estimatedHeartRateBpm: row.estimatedHeartRateBpm,
    heartRateSource: HeartRateSource.values.byName(row.heartRateSource),
    faceColorFeature: row.faceColorFeature,
    selfCondition: row.selfCondition,
    bodyTemperatureC: row.bodyTemperatureC,
    temperatureSource: TemperatureSource.values.byName(row.temperatureSource),
    reportText: row.reportText,
    aiMode: row.aiMode == null ? null : ReportMode.values.byName(row.aiMode!),
  );

  @override
  Future<List<HealthCheckResult>> loadAll() async =>
      (await _query().get()).map(_decode).toList();

  @override
  Stream<List<HealthCheckResult>> watchAll() =>
      _query().watch().map((rows) => rows.map(_decode).toList());

  @override
  Future<void> deleteOne(String id) async {
    await (_database.delete(
      _database.healthRecords,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> deleteAll() async {
    await _database.delete(_database.healthRecords).go();
  }
}

/// Uses the supplied database without taking ownership of its connection.
class DriftOnboardingStore implements OnboardingStore {
  DriftOnboardingStore(this._database);

  final AppDatabase _database;

  @override
  Future<bool> hasCompletedOnboarding() async {
    final row = await (_database.select(
      _database.onboardingCompletions,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> completeOnboarding() async {
    await _database
        .into(_database.onboardingCompletions)
        .insert(
          const OnboardingCompletionsCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
