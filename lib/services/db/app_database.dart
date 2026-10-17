import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/health_check_result.dart';
import '../settings/onboarding_store.dart';

part 'app_database.g.dart';

/// A singleton row exists only after the introductory explanation is completed.
class OnboardingCompletions extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stores [DateTime] as microseconds since the Unix epoch. Drift's default
/// keeps whole seconds only, which would silently drop measurement precision.
/// Values read back are in local time.
class _MicrosecondsConverter extends TypeConverter<DateTime, int> {
  const _MicrosecondsConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

/// One row per [HealthCheckResult]; the ID is issued by C and kept as-is.
/// Unmeasured values are NULL, never 0. Enums are stored by name, so
/// reordering them does not corrupt existing rows. [elapsedMicros] holds
/// `Duration.inMicroseconds`.
class HealthRecords extends Table {
  TextColumn get id => text()();
  IntColumn get measuredAt => integer().map(const _MicrosecondsConverter())();
  IntColumn get elapsedMicros => integer()();
  BoolColumn get faceDetected => boolean()();
  TextColumn get quality => textEnum<MeasurementQuality>()();
  RealColumn get estimatedHeartRateBpm => real().nullable()();
  TextColumn get heartRateSource => textEnum<HeartRateSource>()();
  RealColumn get faceColorFeature => real().nullable()();
  IntColumn get selfCondition => integer().nullable()();
  RealColumn get bodyTemperatureC => real().nullable()();
  TextColumn get temperatureSource => textEnum<TemperatureSource>()();
  TextColumn get reportText => text().nullable()();
  TextColumn get aiMode => textEnum<ReportMode>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The application owns this connection and must await [close] on disposal.
@DriftDatabase(tables: [OnboardingCompletions, HealthRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'os_2604'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 -> v2 only adds the health record table; onboarding data is kept.
      if (from < 2) await m.createTable(healthRecords);
    },
  );
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
