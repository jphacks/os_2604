import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';

void main() {
  test('defaults to off and round-trips', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftReminderSettingsStore(db);
    final initial = await store.load();
    expect((initial.enabled, initial.hour, initial.minute), (false, 8, 0));

    await store.save(
      const ReminderSettings(enabled: true, hour: 6, minute: 45),
    );
    await store.save(const ReminderSettings(enabled: true, hour: 7, minute: 5));
    final loaded = await store.load();
    expect((loaded.enabled, loaded.hour, loaded.minute), (true, 7, 5));
    expect(await db.select(db.reminderPreferences).get(), hasLength(1));
  });

  test('migration v2 -> v3 keeps records and onboarding', () async {
    final v2 = NativeDatabase.memory(
      setup: (db) {
        db.execute(
          'CREATE TABLE onboarding_completions (id INTEGER NOT NULL '
          'CHECK (id = 1), PRIMARY KEY (id))',
        );
        db.execute('INSERT INTO onboarding_completions (id) VALUES (1)');
        db.execute(
          'CREATE TABLE health_records ('
          'id TEXT NOT NULL, measured_at INTEGER NOT NULL, '
          'elapsed_micros INTEGER NOT NULL, face_detected INTEGER NOT NULL, '
          'quality TEXT NOT NULL, estimated_heart_rate_bpm REAL, '
          'heart_rate_source TEXT NOT NULL, face_color_feature REAL, '
          'self_condition INTEGER, body_temperature_c REAL, '
          'temperature_source TEXT NOT NULL, report_text TEXT, ai_mode TEXT, '
          'PRIMARY KEY (id))',
        );
        db.execute(
          "INSERT INTO health_records VALUES ('old', 1790000000000000, "
          "15000000, 1, 'good', NULL, 'none', NULL, 4, NULL, 'none', NULL, NULL)",
        );
        db.execute('PRAGMA user_version = 2');
      },
    );
    final migrated = AppDatabase(v2);
    addTearDown(migrated.close);

    expect(
      await DriftOnboardingStore(migrated).hasCompletedOnboarding(),
      isTrue,
    );
    final old = await HealthRecordRepository(migrated).findById('old');
    expect(old, isNotNull);
    expect(old!.selfCondition, 4);
    expect(old.quality, MeasurementQuality.good);

    final store = DriftReminderSettingsStore(migrated);
    expect((await store.load()).enabled, isFalse);
    await store.save(const ReminderSettings(enabled: true));
    expect((await store.load()).enabled, isTrue);
  });
}
