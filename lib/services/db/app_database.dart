import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/health_check_result.dart';
import '../settings/onboarding_store.dart';
import '../settings/feedback_settings_store.dart';
import '../settings/scan_mode_store.dart';
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

class ScanPreferences extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  BoolColumn get research => boolean()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FeedbackPreferences extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  BoolColumn get sound => boolean()();
  BoolColumn get haptics => boolean()();
  TextColumn get instrument => textEnum<MeasureInstrument>().withDefault(
    Constant(MeasureInstrument.marimba.name),
  )();
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

/// Optional, one-to-one environment snapshot. Parent deletion removes it.
class HealthRecordEnvironments extends Table {
  @override
  String get tableName => 'health_record_environment';
  TextColumn get recordId =>
      text().references(HealthRecords, #id, onDelete: KeyAction.cascade)();
  TextColumn get state => text()();
  RealColumn get ambientTemperatureC => real().nullable()();
  RealColumn get relativeHumidityPct => real().nullable()();
  TextColumn get source => text()();
  IntColumn get receivedAtUtcMicros => integer().nullable()();
  IntColumn get sampleAgeAtSnapshotMicros => integer().nullable()();
  IntColumn get sampleSequence => integer().nullable()();
  IntColumn get protocolVersion => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {recordId};
  @override
  List<String> get customConstraints => [
    "CHECK (source = 'e84_sht40')",
    "CHECK ((state = 'available' AND ambient_temperature_c IS NOT NULL AND relative_humidity_pct IS NOT NULL AND ambient_temperature_c BETWEEN -40 AND 125 AND relative_humidity_pct BETWEEN 0 AND 100 AND received_at_utc_micros IS NOT NULL AND sample_age_at_snapshot_micros BETWEEN 0 AND 5000000 AND sample_age_at_snapshot_micros IS NOT NULL AND sample_sequence BETWEEN 0 AND 4294967295 AND sample_sequence IS NOT NULL AND protocol_version = 1 AND protocol_version IS NOT NULL) OR (state <> 'available' AND ambient_temperature_c IS NULL AND relative_humidity_pct IS NULL AND sample_age_at_snapshot_micros IS NULL))",
  ];
}

/// The application owns this connection and must await [close] on disposal.
@DriftDatabase(
  tables: [
    OnboardingCompletions,
    HealthRecords,
    ReminderPreferences,
    ScanPreferences,
    HealthRecordEnvironments,
    FeedbackPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'os_2604'));

  @override
  int get schemaVersion => 9;

  Future<bool> _tableExists(String name) async => (await customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    variables: [Variable.withString(name)],
  ).get()).isNotEmpty;

  Future<bool> _columnExists(String table, String column) async =>
      (await customSelect(
        'PRAGMA table_info($table)',
      ).get()).any((c) => c.read<String>('name') == column);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
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
      if (from < 6) await m.createTable(scanPreferences);
      if (from >= 2 && from < 5) {
        // A device can still report v4 after scan_mode was already added.
        // Keep that column and its values only if its definition matches v5.
        final columns = await customSelect('PRAGMA table_info(health_records)')
            .get();
        final existing = columns.where(
          (column) => column.read<String>('name').toLowerCase() == 'scan_mode',
        );
        if (existing.isEmpty) {
          await m.addColumn(healthRecords, healthRecords.scanMode);
        } else {
          final column = existing.single;
          if (column.read<String>('type').toUpperCase() != 'TEXT' ||
              column.read<int>('notnull') != 1 ||
              column.readNullable<String>('dflt_value') != "'legacyUnknown'" ||
              column.read<int>('pk') != 0) {
            throw StateError(
              'Unexpected health_records.scan_mode schema; '
              'migration stopped to preserve existing records.',
            );
          }
        }
      }
      if (from < 7) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'health_record_environment'",
        ).get();
        if (existing.isNotEmpty) {
          throw StateError(
            'Unexpected existing environment table; migration stopped to preserve records.',
          );
        }
        await m.createTable(healthRecordEnvironments);
      }
      // v7/v8 existed on two branches: main's v7 added the environment table,
      // while the sound branch used v7 (sound/haptics) and v8 (instrument).
      // Decide by what actually exists so neither side loses rows.
      if (from >= 7 &&
          from < 9 &&
          !await _tableExists('health_record_environment')) {
        await m.createTable(healthRecordEnvironments);
      }
      if (from < 9) {
        if (!await _tableExists('feedback_preferences')) {
          await m.createTable(feedbackPreferences);
        } else if (!await _columnExists('feedback_preferences', 'instrument')) {
          await m.addColumn(
            feedbackPreferences,
            feedbackPreferences.instrument,
          );
        }
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

class DriftScanModeStore implements ScanModeStore {
  DriftScanModeStore(this.database);
  final AppDatabase database;
  @override
  Future<bool> loadResearchMode() async =>
      (await database.select(database.scanPreferences).getSingleOrNull())
          ?.research ??
      false;
  @override
  Future<void> saveResearchMode(bool enabled) async {
    await database
        .into(database.scanPreferences)
        .insertOnConflictUpdate(
          ScanPreferencesCompanion.insert(
            id: const Value(1),
            research: enabled,
          ),
        );
  }
}

class DriftFeedbackSettingsStore implements FeedbackSettingsStore {
  DriftFeedbackSettingsStore(this.database);
  final AppDatabase database;

  @override
  Future<FeedbackSettings> load() async {
    final row = await database
        .select(database.feedbackPreferences)
        .getSingleOrNull();
    return row == null
        ? const FeedbackSettings()
        : FeedbackSettings(
            sound: row.sound,
            haptics: row.haptics,
            instrument: row.instrument,
          );
  }

  @override
  Future<void> save(FeedbackSettings settings) async {
    await database
        .into(database.feedbackPreferences)
        .insertOnConflictUpdate(
          FeedbackPreferencesCompanion.insert(
            id: const Value(1),
            sound: settings.sound,
            haptics: settings.haptics,
            instrument: Value(settings.instrument),
          ),
        );
  }
}
