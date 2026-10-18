import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/feedback_settings_store.dart';

void main() {
  test(
    'v6 upgrade keeps records; sound/haptics default on and survive reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'feedback-preferences-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      await HealthRecordRepository(db).insert(
        HealthCheckResult(
          id: 'synthetic',
          measuredAt: DateTime(2026, 10, 18),
          elapsed: const Duration(seconds: 15),
          faceDetected: true,
          quality: MeasurementQuality.good,
        ),
      );
      await DriftScanModeStore(db).saveResearchMode(true);
      // v6 には環境の表も音の表もない。
      await db.customStatement('DROP TABLE feedback_preferences');
      await db.customStatement('DROP TABLE health_record_environment');
      await db.customStatement('PRAGMA user_version = 6');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final store = DriftFeedbackSettingsStore(db);
      final initial = await store.load();
      expect((initial.sound, initial.haptics), (true, true));
      expect(await HealthRecordRepository(db).findById('synthetic'), isNotNull);
      expect(await DriftScanModeStore(db).loadResearchMode(), isTrue);
      await store.save(const FeedbackSettings(sound: false, haptics: true));
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final reopened = await DriftFeedbackSettingsStore(db).load();
      expect((reopened.sound, reopened.haptics), (false, true));
      await db.close();
    },
  );

  test('v7 upgrade adds the instrument (marimba) and keeps sound/haptics', () async {
    final dir = await Directory.systemTemp.createTemp('feedback-instrument-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await HealthRecordRepository(db).insert(
      HealthCheckResult(
        id: 'synthetic',
        measuredAt: DateTime(2026, 10, 18),
        elapsed: const Duration(seconds: 15),
        faceDetected: true,
        quality: MeasurementQuality.good,
      ),
    );
    // v7 の形（楽器の列なし）に戻して、音オフ・振動オンを保存しておく。
    await db.customStatement('DROP TABLE feedback_preferences');
    await db.customStatement(
      'CREATE TABLE feedback_preferences (id INTEGER NOT NULL CHECK (id = 1), '
      'sound INTEGER NOT NULL, haptics INTEGER NOT NULL, PRIMARY KEY (id))',
    );
    await db.customStatement(
      'INSERT INTO feedback_preferences (id, sound, haptics) VALUES (1, 0, 1)',
    );
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final store = DriftFeedbackSettingsStore(db);
    final migrated = await store.load();
    expect(
      (migrated.sound, migrated.haptics, migrated.instrument),
      (false, true, MeasureInstrument.marimba),
    );
    expect(await HealthRecordRepository(db).findById('synthetic'), isNotNull);
    await store.save(migrated.copyWith(instrument: MeasureInstrument.koto));
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect(
      (await DriftFeedbackSettingsStore(db).load()).instrument,
      MeasureInstrument.koto,
    );
    await db.close();
  });

  test(
    'main v7 (environment table, no sound table) gains default sound settings',
    () async {
      final dir = await Directory.systemTemp.createTemp('feedback-main-v7-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      await HealthRecordRepository(db).insert(
        HealthCheckResult(
          id: 'synthetic',
          measuredAt: DateTime(2026, 10, 18),
          elapsed: const Duration(seconds: 15),
          faceDetected: true,
          quality: MeasurementQuality.good,
        ),
      );
      await db.customStatement('DROP TABLE feedback_preferences');
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final loaded = await DriftFeedbackSettingsStore(db).load();
      expect(
        (loaded.sound, loaded.haptics, loaded.instrument),
        (true, true, MeasureInstrument.marimba),
      );
      expect(await HealthRecordRepository(db).findById('synthetic'), isNotNull);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        9,
      );
      await DriftFeedbackSettingsStore(db)
          .save(const FeedbackSettings(sound: false));
      expect((await DriftFeedbackSettingsStore(db).load()).sound, isFalse);
      await db.close();
    },
  );

  test(
    'a removed instrument saved earlier (kalimba) falls back to marimba',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO feedback_preferences (id, sound, haptics, instrument) "
        "VALUES (1, 1, 0, 'kalimba')",
      );
      final loaded = await DriftFeedbackSettingsStore(db).load();
      expect(
        (loaded.sound, loaded.haptics, loaded.instrument),
        (true, false, MeasureInstrument.marimba),
      );
      expect(
        MeasureInstrument.fromStored('glockenspiel'),
        MeasureInstrument.marimba,
      );
      expect(MeasureInstrument.fromStored('koto'), MeasureInstrument.koto);
    },
  );
}
