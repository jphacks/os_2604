import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/environment_snapshot.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/db/environment_record_repository.dart';
import 'package:os_2604/services/device/environment_save_service.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';
import 'package:os_2604/screens/result_screen.dart';

import '../support/fake_scan.dart';
import '../support/fake_reminder.dart';
import '../support/fake_led_transport.dart';

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

void main() {
  for (final hasEnvironment in [true, false]) {
    testWidgets(
      'history reopens stored environment=$hasEnvironment, separate from body temperature',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repository = HealthRecordRepository(db);
        final environment = EnvironmentRecordRepository(db);
        final saves = EnvironmentSaveService(environment);
        final ai = runnerOf(FakeAiClient());
        final led = hasEnvironment
            ? LedNotificationService(FakeLedTransport())
            : null;
        addTearDown(() async {
          led?.dispose();
          saves.dispose();
          ai.dispose();
          await db.close();
        });
        tester.view.physicalSize = const Size(1000, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await repository.insert(
          HealthCheckResult(
            id: 'synthetic-history',
            measuredAt: DateTime.utc(2026, 10, 17),
            elapsed: const Duration(seconds: 15),
            faceDetected: true,
            quality: MeasurementQuality.good,
            bodyTemperatureC: 36.5,
            temperatureSource: TemperatureSource.manual,
          ),
        );
        if (hasEnvironment) {
          await environment.attach(
            'synthetic-history',
            EnvironmentSnapshot(
              state: EnvironmentState.available,
              ambientTemperatureC: -1.234,
              relativeHumidityPct: 0,
              receivedAt: DateTime.utc(2026, 10, 17),
              sampleAgeAtSnapshot: const Duration(seconds: 5),
              sampleSequence: 1,
              protocolVersion: 1,
            ),
          );
        }
        await tester.pumpWidget(
          MorningCheckApp(
            onboardingStore: _Done(),
            repository: repository,
            aiRunner: ai,
            reminderService: FakeReminderService(),
            reminderStore: FakeReminderStore(),
            createScanSession: () => sessionOf(FakeScanService()),
            environmentSaves: saves,
            ledService: led,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('履歴'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(formatRecordDate(DateTime.utc(2026, 10, 17))),
        );
        await tester.pumpAndSettle();
        expect(find.text('36.5 ℃（手入力）'), findsOneWidget);
        if (hasEnvironment) {
          expect(find.text('現在のキット接続・LED状態'), findsOneWidget);
          expect(find.text('キット未接続'), findsOneWidget);
          expect(find.text('計測時に保存したキット付近の環境'), findsOneWidget);
          expect(find.text('下の環境情報は、計測終了時に保存した記録です。'), findsOneWidget);
          expect(find.text('キット付近の室温：-1.2 ℃'), findsOneWidget);
          expect(find.text('キット付近の相対湿度：0.0 %RH'), findsOneWidget);
          expect(find.textContaining('iPhone受信日時：'), findsOneWidget);
        } else {
          expect(find.text('環境情報の保存なし'), findsOneWidget);
          expect(find.textContaining('キット未接続'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}
