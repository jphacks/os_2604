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
        await repository.insert(
          HealthCheckResult(
            id: 'synthetic-older',
            measuredAt: DateTime.utc(2026, 10, 16),
            elapsed: const Duration(seconds: 15),
            faceDetected: true,
            quality: MeasurementQuality.good,
          ),
        );
        await environment.attach(
          'synthetic-older',
          EnvironmentSnapshot(state: EnvironmentState.disabled),
        );
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
        await tester.tap(
          find.byKey(const ValueKey('history-row-synthetic-history')),
        );
        await tester.pumpAndSettle();
        expect(find.text('36.5℃'), findsOneWidget);
        expect(find.text('体温計（手入力）'), findsOneWidget);
        // キットは「この日の記録」と同じ作りのカード（接続・室温・湿度の行）。
        expect(find.text('キット'), findsOneWidget);
        expect(find.text('室温'), findsOneWidget);
        expect(find.text('湿度'), findsOneWidget);
        if (hasEnvironment) {
          expect(find.text('キットの接続'), findsOneWidget);
          expect(find.text('未接続'), findsOneWidget); // 今の接続状態
          expect(find.text('-1.2 ℃'), findsOneWidget);
          expect(find.text('0.0 %RH'), findsOneWidget);
          expect(find.text('キット付近・計測終了時'), findsNWidgets(2));
          expect(find.textContaining('受信：'), findsOneWidget);
        } else {
          expect(find.text('環境情報の保存なし'), findsOneWidget);
          expect(find.text('キットの接続'), findsNothing);
          expect(find.text('未測定'), findsNWidgets(2)); // 0や正常値で埋めない
        }
        // 前後の記録へ移っても、最初の環境ストリームを表示し続けない。
        await tester.tap(find.byTooltip('古い記録'));
        await tester.pumpAndSettle();
        expect(find.text('環境情報の取得はオフです'), findsNWidgets(2));
        expect(find.text('未測定'), findsNWidgets(2));
        expect(find.text('-1.2 ℃'), findsNothing);
        await tester.tap(find.byTooltip('新しい記録'));
        await tester.pumpAndSettle();
        expect(find.text('環境情報の取得はオフです'), findsNothing);
        expect(
          find.text(hasEnvironment ? '-1.2 ℃' : '環境情報の保存なし'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}
