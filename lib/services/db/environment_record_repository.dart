import 'package:drift/drift.dart';

import '../../models/environment_snapshot.dart';
import 'app_database.dart';

abstract interface class EnvironmentRecordStore {
  /// False means the parent was deleted. Never recreates or replaces a record.
  Future<bool> attach(String recordId, EnvironmentSnapshot snapshot);
  Stream<EnvironmentSnapshot?> watch(String recordId);
}

class EnvironmentRecordRepository implements EnvironmentRecordStore {
  EnvironmentRecordRepository(this.database);
  final AppDatabase database;

  @override
  Future<bool> attach(String recordId, EnvironmentSnapshot snapshot) =>
      database.transaction(() async {
        final parent = await (database.select(
          database.healthRecords,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (parent == null) return false;
        await database
            .into(database.healthRecordEnvironments)
            .insert(
              HealthRecordEnvironmentsCompanion.insert(
                recordId: recordId,
                state: snapshot.state.name,
                source: EnvironmentSnapshot.source,
                ambientTemperatureC: Value(snapshot.ambientTemperatureC),
                relativeHumidityPct: Value(snapshot.relativeHumidityPct),
                receivedAtUtcMicros: Value(
                  snapshot.receivedAt?.microsecondsSinceEpoch,
                ),
                sampleAgeAtSnapshotMicros: Value(
                  snapshot.sampleAgeAtSnapshot?.inMicroseconds,
                ),
                sampleSequence: Value(snapshot.sampleSequence),
                protocolVersion: Value(snapshot.protocolVersion),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        return true;
      });

  @override
  Stream<EnvironmentSnapshot?> watch(String recordId) =>
      (database.select(
        database.healthRecordEnvironments,
      )..where((t) => t.recordId.equals(recordId))).watchSingleOrNull().map(
        (r) => r == null
            ? null
            : EnvironmentSnapshot(
                state: EnvironmentState.values.byName(r.state),
                ambientTemperatureC: r.ambientTemperatureC,
                relativeHumidityPct: r.relativeHumidityPct,
                receivedAt: r.receivedAtUtcMicros == null
                    ? null
                    : DateTime.fromMicrosecondsSinceEpoch(
                        r.receivedAtUtcMicros!,
                        isUtc: true,
                      ),
                sampleAgeAtSnapshot: r.sampleAgeAtSnapshotMicros == null
                    ? null
                    : Duration(microseconds: r.sampleAgeAtSnapshotMicros!),
                sampleSequence: r.sampleSequence,
                protocolVersion: r.protocolVersion,
              ),
      );
}
