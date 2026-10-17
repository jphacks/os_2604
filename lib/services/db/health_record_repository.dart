import 'package:drift/drift.dart';

import '../../models/health_check_result.dart';
import '../analysis/history_baseline.dart';
import 'app_database.dart';
import 'health_record_store.dart';

/// Persists [HealthCheckResult]s using the supplied database without taking
/// ownership of its connection. Rows are rebuilt through the model
/// constructor, so corrupt data surfaces as an error instead of a fake value.
class HealthRecordRepository implements HealthRecordStore {
  HealthRecordRepository(this._database);

  final AppDatabase _database;

  $HealthRecordsTable get _table => _database.healthRecords;

  /// Throws if a record with the same ID already exists.
  @override
  Future<void> insert(HealthCheckResult result) async {
    await _database.into(_table).insert(_toCompanion(result));
  }

  /// Appends the self-reported condition (1..5) to an existing record.
  Future<void> updateSelfCondition(String id, int selfCondition) =>
      _update(id, (r) => _copy(r, selfCondition: selfCondition));

  /// Appends a body temperature together with its source.
  Future<void> updateTemperature(
    String id,
    double celsius,
    TemperatureSource source,
  ) => _update(
    id,
    (r) => _copy(r, bodyTemperatureC: celsius, temperatureSource: source),
  );

  /// Appends the generated report together with the mode actually used.
  Future<void> updateReport(String id, String text, ReportMode mode) =>
      _update(id, (r) => _copy(r, reportText: text, aiMode: mode));

  Future<HealthCheckResult?> findById(String id) async {
    final row = await (_database.select(
      _table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Records with `from <= measuredAt < to`, newest first.
  Future<List<HealthCheckResult>> findInRange(
    DateTime from,
    DateTime to,
  ) async {
    final rows =
        await (_database.select(_table)
              ..where(
                (t) =>
                    t.measuredAt.isBiggerOrEqualValue(
                      from.microsecondsSinceEpoch,
                    ) &
                    t.measuredAt.isSmallerThanValue(to.microsecondsSinceEpoch),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  /// Input for [calculateHistoryBaseline]; only good-quality scans are valid.
  Future<List<BaselineObservation>> baselineObservations(
    DateTime from,
    DateTime to,
  ) async => [
    for (final r in await findInRange(from, to))
      (
        measuredAt: r.measuredAt,
        isValid: r.quality == MeasurementQuality.good,
        selfCondition: r.selfCondition,
      ),
  ];

  /// All records, newest first, re-emitted on every change.
  @override
  Stream<List<HealthCheckResult>> watchAll() =>
      (_database.select(_table)
            ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)]))
          .watch()
          .map((rows) => rows.map(_fromRow).toList());

  @override
  Future<void> deleteOne(String id) => delete(id);

  Future<void> delete(String id) async {
    await (_database.delete(_table)..where((t) => t.id.equals(id))).go();
  }

  /// Leaves the onboarding table untouched.
  @override
  Future<void> deleteAll() async {
    await _database.delete(_table).go();
  }

  @override
  Future<List<HealthCheckResult>> loadAll() async =>
      (await (_database.select(
            _table,
          )..orderBy([(t) => OrderingTerm.desc(t.measuredAt)])).get())
          .map(_fromRow)
          .toList();

  /// Replaces only the optional inputs and report of the row with the same ID.
  /// Returns false, without recreating the row, if it was deleted meanwhile.
  @override
  Future<bool> updateInputsAndReport(HealthCheckResult result) =>
      _database.transaction(() async {
        final c = await findById(result.id);
        if (c == null) return false;
        final updated = HealthCheckResult(
          id: c.id,
          measuredAt: c.measuredAt,
          elapsed: c.elapsed,
          faceDetected: c.faceDetected,
          quality: c.quality,
          scanMode: c.scanMode,
          estimatedHeartRateBpm: c.estimatedHeartRateBpm,
          heartRateSource: c.heartRateSource,
          faceColorFeature: c.faceColorFeature,
          selfCondition: result.selfCondition,
          bodyTemperatureC: result.bodyTemperatureC,
          temperatureSource: result.temperatureSource,
          reportText: result.reportText,
          aiMode: result.aiMode,
        );
        await (_database.update(
          _table,
        )..where((t) => t.id.equals(c.id))).write(_toCompanion(updated));
        return true;
      });

  Future<void> _update(
    String id,
    HealthCheckResult Function(HealthCheckResult) change,
  ) => _database.transaction(() async {
    final current = await findById(id);
    if (current == null) throw StateError('No health record with ID $id.');
    final updated = change(current); // Validates via the model constructor.
    await (_database.update(
      _table,
    )..where((t) => t.id.equals(id))).write(_toCompanion(updated));
  });

  static HealthCheckResult _copy(
    HealthCheckResult r, {
    int? selfCondition,
    double? bodyTemperatureC,
    TemperatureSource? temperatureSource,
    String? reportText,
    ReportMode? aiMode,
  }) => HealthCheckResult(
    id: r.id,
    measuredAt: r.measuredAt,
    elapsed: r.elapsed,
    faceDetected: r.faceDetected,
    quality: r.quality,
    scanMode: r.scanMode,
    estimatedHeartRateBpm: r.estimatedHeartRateBpm,
    heartRateSource: r.heartRateSource,
    faceColorFeature: r.faceColorFeature,
    selfCondition: selfCondition ?? r.selfCondition,
    bodyTemperatureC: bodyTemperatureC ?? r.bodyTemperatureC,
    temperatureSource: temperatureSource ?? r.temperatureSource,
    reportText: reportText ?? r.reportText,
    aiMode: aiMode ?? r.aiMode,
  );

  static HealthRecordsCompanion _toCompanion(HealthCheckResult r) =>
      HealthRecordsCompanion(
        id: Value(r.id),
        measuredAt: Value(r.measuredAt),
        elapsedMicros: Value(r.elapsed.inMicroseconds),
        faceDetected: Value(r.faceDetected),
        quality: Value(r.quality),
        scanMode: Value(r.scanMode),
        estimatedHeartRateBpm: Value(r.estimatedHeartRateBpm),
        heartRateSource: Value(r.heartRateSource),
        faceColorFeature: Value(r.faceColorFeature),
        selfCondition: Value(r.selfCondition),
        bodyTemperatureC: Value(r.bodyTemperatureC),
        temperatureSource: Value(r.temperatureSource),
        reportText: Value(r.reportText),
        aiMode: Value(r.aiMode),
      );

  static HealthCheckResult _fromRow(HealthRecord row) => HealthCheckResult(
    id: row.id,
    measuredAt: row.measuredAt,
    elapsed: Duration(microseconds: row.elapsedMicros),
    faceDetected: row.faceDetected,
    quality: row.quality,
    scanMode: row.scanMode,
    estimatedHeartRateBpm: row.estimatedHeartRateBpm,
    heartRateSource: row.heartRateSource,
    faceColorFeature: row.faceColorFeature,
    selfCondition: row.selfCondition,
    bodyTemperatureC: row.bodyTemperatureC,
    temperatureSource: row.temperatureSource,
    reportText: row.reportText,
    aiMode: row.aiMode,
  );
}

/// B/C-facing store: same storage as [HealthRecordRepository], but like the
/// original interface contract it only accepts successful measurements.
class DriftHealthRecordStore extends HealthRecordRepository {
  DriftHealthRecordStore(super.database);

  @override
  Future<void> insert(HealthCheckResult result) async {
    if (result.quality != MeasurementQuality.good) {
      throw ArgumentError('Only successful measurements can be saved.');
    }
    await super.insert(result);
  }
}
