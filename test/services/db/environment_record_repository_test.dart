import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/environment_snapshot.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/db/environment_record_repository.dart';
import 'package:os_2604/services/device/environment_save_service.dart';

EnvironmentSnapshot syntheticSnapshot([double temperature = -1.234]) =>
    EnvironmentSnapshot(
      state: EnvironmentState.available,
      ambientTemperatureC: temperature,
      relativeHumidityPct: 0,
      receivedAt: DateTime.utc(2026, 10, 18, 0, 0, 0, 1, 2),
      sampleAgeAtSnapshot: const Duration(microseconds: 4999999),
      sampleSequence: 0,
      protocolVersion: 1,
    );
HealthCheckResult syntheticRecord(String id) => HealthCheckResult(
  id: id,
  measuredAt: DateTime.utc(2026, 10, 18),
  elapsed: const Duration(seconds: 15),
  faceDetected: true,
  quality: MeasurementQuality.good,
  scanMode: ScanMode.research,
);

class _GateStore implements EnvironmentRecordStore {
  _GateStore(this.delegate);
  final EnvironmentRecordStore delegate;
  bool fail = true;
  final snapshots = <EnvironmentSnapshot>[];
  Completer<void>? gate;
  @override
  Future<bool> attach(String id, EnvironmentSnapshot snapshot) async {
    snapshots.add(snapshot);
    await gate?.future;
    if (fail) throw StateError('synthetic storage failure');
    return delegate.attach(id, snapshot);
  }

  @override
  Stream<EnvironmentSnapshot?> watch(String id) => delegate.watch(id);
}

void main() {
  late AppDatabase db;
  late HealthRecordRepository health;
  late EnvironmentRecordRepository environment;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    health = HealthRecordRepository(db);
    environment = EnvironmentRecordRepository(db);
  });
  tearDown(() => db.close());

  test('pair precision, source, receive time and frozen age survive updates; attach never overwrites', () async {
    await health.insert(syntheticRecord('one'));
    expect(await environment.attach('one', syntheticSnapshot()), isTrue);
    await health.updateSelfCondition('one', 4);
    await health.updateTemperature('one', 36.5, TemperatureSource.manual);
    await health.updateReport('one', 'synthetic report', ReportMode.template);
    await environment.attach('one', syntheticSnapshot(99));
    final saved = (await environment.watch('one').first)!;
    expect(saved.ambientTemperatureC, -1.234);
    expect(saved.relativeHumidityPct, 0);
    expect(saved.sampleAgeAtSnapshot, const Duration(microseconds: 4999999));
    expect(saved.receivedAt, syntheticSnapshot().receivedAt);
    expect((await health.findById('one'))!.scanMode, ScanMode.research);
    expect(
      (await db
              .customSelect('SELECT source FROM health_record_environment')
              .getSingle())
          .read<String>('source'),
      'e84_sht40',
    );
  });
  test(
    'unavailable is a null pair; old records have no environment row',
    () async {
      for (final state in EnvironmentState.values.where(
        (s) => s != EnvironmentState.available,
      )) {
        await health.insert(syntheticRecord(state.name));
        await environment.attach(state.name, EnvironmentSnapshot(state: state));
        final saved = (await environment.watch(state.name).first)!;
        expect(saved.state, state);
        expect(saved.ambientTemperatureC, isNull);
        expect(saved.relativeHumidityPct, isNull);
      }
      await health.insert(syntheticRecord('old'));
      expect(await environment.watch('old').first, isNull);
    },
  );
  test('foreign keys active; individual/all deletion and late write cannot orphan or recreate', () async {
    expect(
      (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
        'foreign_keys',
      ),
      1,
    );
    for (final id in ['one', 'two']) {
      await health.insert(syntheticRecord(id));
      await environment.attach(id, syntheticSnapshot());
    }
    await health.deleteOne('one');
    expect(await environment.watch('one').first, isNull);
    expect(await environment.attach('one', syntheticSnapshot()), isFalse);
    expect(await health.findById('one'), isNull);
    await health.deleteAll();
    expect(await environment.watch('two').first, isNull);
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
    await expectLater(
      db.customStatement(
        "INSERT INTO health_record_environment (record_id,state,source) VALUES ('missing','disabled','e84_sht40')",
      ),
      throwsException,
    );
  });
  test('environment failure retains parent and retries identical snapshot once, including deletion race', () async {
    await health.insert(syntheticRecord('one'));
    final gate = _GateStore(environment);
    final saves = EnvironmentSaveService(gate);
    addTearDown(saves.dispose);
    final snapshot = syntheticSnapshot();
    final failed = Completer<void>();
    saves.addListener(() {
      if (saves.stateFor('one') == EnvironmentSaveState.failed &&
          !failed.isCompleted) {
        failed.complete();
      }
    });
    saves.savedHealthRecord('one', snapshot);
    await failed.future;
    expect(await health.findById('one'), isNotNull);
    expect(await environment.watch('one').first, isNull);
    gate.fail = false;
    gate.gate = Completer<void>();
    final deleted = Completer<void>();
    saves.addListener(() {
      if (saves.stateFor('one') == EnvironmentSaveState.deleted &&
          !deleted.isCompleted) {
        deleted.complete();
      }
    });
    saves.retry('one');
    saves.retry('one');
    await health.deleteOne('one');
    gate.gate!.complete();
    await deleted.future;
    expect(gate.snapshots, hasLength(2));
    expect(identical(gate.snapshots.first, gate.snapshots.last), isTrue);
    expect(await health.loadAll(), isEmpty);
    expect(await environment.watch('one').first, isNull);
  });

  for (final version in [4, 5, 6]) {
    test(
      'v$version preserves all existing values/settings and adds optional table; reopen enables FK',
      () async {
        await db.close();
        final dir = await Directory.systemTemp.createTemp(
          'environment-migration-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/synthetic.sqlite');
        var old = AppDatabase(NativeDatabase(file));
        await DriftOnboardingStore(old).completeOnboarding();
        await DriftScanModeStore(old).saveResearchMode(true);
        await HealthRecordRepository(old).insert(syntheticRecord('legacy'));
        await old.customStatement('DROP TABLE health_record_environment');
        if (version < 6) {
          await old.customStatement('DROP TABLE scan_preferences');
        }
        final before =
            (await old.customSelect('SELECT * FROM health_records').getSingle())
                .data;
        await old.customStatement('PRAGMA user_version = $version');
        await old.close();
        for (var opening = 0; opening < 2; opening++) {
          old = AppDatabase(NativeDatabase(file));
          expect(
            (await old.customSelect('SELECT * FROM health_records').getSingle())
                .data,
            before,
          );
          expect(
            await DriftOnboardingStore(old).hasCompletedOnboarding(),
            isTrue,
          );
          expect(
            await DriftScanModeStore(old).loadResearchMode(),
            version == 6,
          );
          final store = EnvironmentRecordRepository(old);
          if (opening == 0) {
            expect(await store.watch('legacy').first, isNull);
            await store.attach('legacy', syntheticSnapshot());
          } else {
            expect(
              (await store.watch('legacy').first)!.ambientTemperatureC,
              -1.234,
            );
            await HealthRecordRepository(old).deleteAll();
            expect(await store.watch('legacy').first, isNull);
          }
          expect(
            (await old.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            9,
          );
          expect(
            (await old.customSelect('PRAGMA foreign_keys').getSingle())
                .read<int>('foreign_keys'),
            1,
          );
          await old.close();
        }
      },
    );
  }
  test(
    'failed v6 table creation rolls back version and leaves records intact',
    () async {
      await db.close();
      final dir = await Directory.systemTemp.createTemp(
        'environment-rollback-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/synthetic.sqlite');
      var seeded = AppDatabase(NativeDatabase(file));
      await HealthRecordRepository(seeded).insert(syntheticRecord('legacy'));
      // A conflicting table intentionally reproduces a failed schema addition.
      await seeded.customStatement('PRAGMA user_version = 6');
      final before =
          (await seeded
                  .customSelect('SELECT * FROM health_records')
                  .getSingle())
              .data;
      await seeded.close();
      seeded = AppDatabase(NativeDatabase(file));
      await expectLater(
        HealthRecordRepository(seeded).loadAll(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unexpected existing environment table'),
          ),
        ),
      );
      await seeded.close();
      var inspected = false;
      final recovered = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            expect(raw.select('PRAGMA user_version').single['user_version'], 6);
            expect(
              Map<String, Object?>.from(
                raw.select('SELECT * FROM health_records').single,
              ),
              before,
            );
            raw.execute('DROP TABLE health_record_environment');
            inspected = true;
          },
        ),
      );
      expect(
        (await HealthRecordRepository(recovered).loadAll()).single.id,
        'legacy',
      );
      expect(inspected, isTrue);
      await recovered.close();
    },
  );
}
