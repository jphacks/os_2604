import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
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
      expect(find.text('記録は保存されました。'), findsOneWidget);
      final first = (await records.loadAll()).single;
      expect(first.id, 'rec-1');
      expect(first.selfCondition, isNull);
      expect(first.reportText, isNull);
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('体調を保存'));
      await tester.pumpAndSettle();
      // 承認済みの挙動: レポートは入力後にボタンで生成する（自動生成しない）。
      final report = find.text('レポートを作成');
      await tester.ensureVisible(report);
      await tester.tap(report);
      await tester.pumpAndSettle();
      final updated = (await records.loadAll()).single;
      expect(updated.id, first.id);
      expect(updated.selfCondition, 4);
      expect(updated.aiMode, ReportMode.template);
      expect(updated.bodyTemperatureC, isNull);
      await tester.ensureVisible(find.text('ホームへ'));
      await tester.tap(find.text('ホームへ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();
      expect(find.textContaining('体調：4 / 5'), findsOneWidget);
      await tester.tap(find.byTooltip('この記録を削除'));
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
      expect(find.text('記録は保存されました。'), findsNothing);
      expect(find.widgetWithText(AppBar, '結果'), findsNothing);
      expect(await records.loadAll(), isEmpty);
      repo.failInsert = false;
      final retry = find.text('保存を再試行');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect((await records.loadAll()).single.id, 'rec-1');
      expect(find.text('記録は保存されました。'), findsOneWidget);
      await unmount(tester);
    },
  );
}
