import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/ai/on_device_ai_client.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_store.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import 'support/fake_scan.dart';
import 'support/fake_reminder.dart';

class _Onboarding implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

void main() {
  late AppDatabase db;
  late FlakyRepository repo;
  late HealthRecordStore records;
  late FakeScanService scan;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FlakyRepository(db);
    records = repo;
    scan = FakeScanService();
  });
  tearDown(() async => db.close());

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    scan = FakeScanService();
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Onboarding(),
        repository: repo,
        aiRunner: runnerOf(FakeAiClient()),
        reminderService: FakeReminderService(),
        reminderStore: FakeReminderStore(),
        createScanSession: () => sessionOf(scan),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始'));
    await tester.pump();
    expect(scan.starts, 1);
  }

  // drift の watch() が残す Timer を流すため、画面を外して時間を進める。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'measurement commits before result/report, then inputs, history and deletion use same ID',
    (tester) async {
      await start(tester);
      expect(await records.loadAll(), isEmpty);
      scan.finish(successOutcome());
      await tester.pumpAndSettle();
      expect(find.text('いまの体調は？'), findsOneWidget);
      final first = (await records.loadAll()).single;
      expect(first.id, 'rec-1');
      expect(first.selfCondition, isNull);
      expect(first.reportText, isNull);
      await tester.tap(find.text('4'));
      await tester.pump();
      // 承認済みの挙動: レポートは入力後にボタンを押して生成する（自動生成しない）。
      await tester.tap(find.text('結果を見る'));
      await tester.pumpAndSettle();
      final updated = (await records.loadAll()).single;
      expect(updated.id, first.id);
      expect(updated.selfCondition, 4);
      expect(updated.aiMode, ReportMode.template);
      expect(updated.bodyTemperatureC, isNull);
      await tester.ensureVisible(find.text('履歴に戻る'));
      await tester.tap(find.text('履歴に戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('history-row-${first.id}'));
      expect(
        find.descendant(of: row, matching: find.text('4')),
        findsOneWidget,
      );
      // 削除は履歴詳細から行う。
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(await records.loadAll(), isEmpty);
      expect(find.text('測定記録はまだありません。'), findsOneWidget);
      await unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed scan never creates a record', (tester) async {
    await start(tester);
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.faceNotFound,
        elapsed: Duration(seconds: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('位置を調整'), findsOneWidget);
    expect(await records.loadAll(), isEmpty);
    await unmount(tester);
  });

  testWidgets(
    'failed insert keeps result for retry and does not show saved screen',
    (tester) async {
      repo.failInsert = true;
      await start(tester);
      scan.finish(successOutcome());
      await tester.pumpAndSettle();
      expect(find.text('いまの体調は？'), findsNothing);
      expect(find.text('計測できました'), findsNothing);
      expect(await records.loadAll(), isEmpty);
      repo.failInsert = false;
      final retry = find.text('保存を再試行');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect((await records.loadAll()).single.id, 'rec-1');
      expect(find.text('いまの体調は？'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'P2 experimental heart rate and face color persist in DB, show on Result/History, and pass to P1 on-device AI report',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final aiClient = FakeAiClient()
        ..availability = AiAvailability.available
        ..response = 'reviewSelfCondition';
      scan = FakeScanService();

      await tester.pumpWidget(
        MorningCheckApp(
          onboardingStore: _Onboarding(),
          repository: repo,
          aiRunner: runnerOf(aiClient),
          reminderService: FakeReminderService(),
          reminderStore: FakeReminderStore(),
          createScanSession: () => sessionOf(scan),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('チェック開始'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('開始'));
      await tester.pump();

      scan.finish(
        ScanSuccess(
          HealthCheckResult(
            id: 'rec-p2-1',
            measuredAt: DateTime(2026, 10, 17, 8, 30),
            elapsed: const Duration(seconds: 15, milliseconds: 100),
            faceDetected: true,
            quality: MeasurementQuality.good,
            estimatedHeartRateBpm: 68.4,
            heartRateSource: HeartRateSource.rppgExperimental,
            faceColorFeature: 1.224,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialRecord = (await records.loadAll()).single;
      expect(initialRecord.id, 'rec-p2-1');
      expect(initialRecord.estimatedHeartRateBpm, 68.4);
      expect(initialRecord.heartRateSource, HeartRateSource.rppgExperimental);
      expect(initialRecord.faceColorFeature, 1.224);

      // 入力画面では心拍を出さない。結果を見るを押すと推定値を参考値として表示する。
      expect(find.text('いまの体調は？'), findsOneWidget);
      expect(find.text('68 bpm'), findsNothing);

      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('結果を見る'));
      await tester.pumpAndSettle();

      expect(find.text('68 bpm'), findsOneWidget);
      expect(find.text('参考値'), findsOneWidget);
      expect(find.text('カメラから推定（研究モード）'), findsOneWidget);
      expect(find.text('1.224'), findsOneWidget);

      expect(aiClient.generations, 1);
      expect(aiClient.prompt, contains('"selfCondition":4'));

      final updatedRecord = (await records.loadAll()).single;
      expect(updatedRecord.aiMode, ReportMode.onDevice);
      expect(updatedRecord.estimatedHeartRateBpm, 68.4);
      expect(updatedRecord.heartRateSource, HeartRateSource.rppgExperimental);
      expect(updatedRecord.faceColorFeature, 1.224);
      expect(updatedRecord.reportText, contains('生成モード：端末内AI（短文選択）'));
      expect(
        updatedRecord.reportText,
        contains('心拍数：68.4 bpm（rPPGによる試験的推定。医療的な実測値ではありません）'),
      );
      expect(find.text('端末内AIで作成'), findsOneWidget);

      await tester.ensureVisible(find.text('履歴に戻る'));
      await tester.tap(find.text('履歴に戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey('history-row-${updatedRecord.id}'));
      expect(
        find.descendant(of: row, matching: find.text('良好')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('4')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('68 bpm'), findsOneWidget);
      expect(find.text('1.224'), findsOneWidget);
      expect(find.text('端末内AIで作成'), findsOneWidget);

      await unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
