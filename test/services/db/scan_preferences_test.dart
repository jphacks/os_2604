import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

void main() {
  test('v5 upgrade preserves health records and defaults to standard; mode survives reopen', () async {
    final dir = await Directory.systemTemp.createTemp('scan-preferences-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final record = HealthCheckResult(
      id: 'synthetic',
      measuredAt: DateTime(2026, 10, 18),
      elapsed: const Duration(seconds: 15),
      faceDetected: true,
      quality: MeasurementQuality.good,
      scanMode: ScanMode.research,
    );
    await HealthRecordRepository(db).insert(record);
    await db.customStatement('DROP TABLE scan_preferences');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    final store = DriftScanModeStore(db);
    expect(await store.loadResearchMode(), isFalse);
    expect(
      (await HealthRecordRepository(db).findById('synthetic'))!.scanMode,
      ScanMode.research,
    );
    await store.saveResearchMode(true);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect(await DriftScanModeStore(db).loadResearchMode(), isTrue);
    await DriftScanModeStore(db).saveResearchMode(false);
    expect(await DriftScanModeStore(db).loadResearchMode(), isFalse);
    await db.close();
  });
}
