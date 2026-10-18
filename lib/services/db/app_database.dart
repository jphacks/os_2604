import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/health_check_result.dart';
import '../settings/onboarding_store.dart';
import '../settings/reminder_settings_store.dart';

part 'app_database.g.dart';

/// A singleton row exists only after the introductory explanation is completed.
class OnboardingCompletions extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Singleton row (id = 1) for the morning reminder; absent means "off".
class ReminderPreferences extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  BoolColumn get enabled => boolean()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();

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
  TextColumn get scanMode =>
      textEnum<ScanMode>().withDefault(const Constant('legacyUnknown'))();
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
@DriftDatabase(
  tables: [OnboardingCompletions, HealthRecords, ReminderPreferences],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'os_2604'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) => transaction(() async {
      // v1 -> v2 only adds the health record table; onboarding data is kept.
      if (from < 2) await m.createTable(healthRecords);
      // v2 -> v3 only adds the reminder table; existing rows are untouched.
      if (from < 3) await m.createTable(reminderPreferences);
      if (from < 4) {
        // Both legacy seconds and current microseconds used schema v2/v3.
        // The user approved converting only seconds in UTC year 2026. Do not
        // guess the unit of other values, or multiply current microseconds.
        await customStatement(
          'UPDATE health_records SET measured_at = measured_at * 1000000 '
          'WHERE measured_at >= ? AND measured_at < ?',
          [
            DateTime.utc(2026).millisecondsSinceEpoch ~/ 1000,
            DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }
      if (from >= 2 && from < 5) {
        await m.addColumn(healthRecords, healthRecords.scanMode);
      }
    }),
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

/// Uses the supplied database without taking ownership of its connection.
class DriftReminderSettingsStore implements ReminderSettingsStore {
  DriftReminderSettingsStore(this._database);

  final AppDatabase _database;

  @override
  Future<ReminderSettings> load() async {
    final row = await (_database.select(
      _database.reminderPreferences,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row == null) return const ReminderSettings();
    return ReminderSettings(
      enabled: row.enabled,
      hour: row.hour,
      minute: row.minute,
    );
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    await _database
        .into(_database.reminderPreferences)
        .insertOnConflictUpdate(
          ReminderPreferencesCompanion.insert(
            id: const Value(1),
            enabled: settings.enabled,
            hour: settings.hour,
            minute: settings.minute,
          ),
        );
  }
}
