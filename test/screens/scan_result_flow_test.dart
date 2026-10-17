import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import '../support/fake_scan.dart';

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

void main() {
  late AppDatabase db;
  late FlakyRepository repo;
  late FakeScanService scan;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FlakyRepository(db);
    scan = FakeScanService();
  });
  tearDown(() async => db.close());

  Future<void> openScan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Done(),
        repository: repo,
        createScanSession: () => sessionOf(scan),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
  }

  Future<void> startAndFinish(WidgetTester tester, ScanOutcome o) async {
    await tester.tap(find.text('開始'));
    await tester.pump();
    scan.finish(o);
    await tester.pumpAndSettle();
  }

  testWidgets('success saves before the result screen; nulls are 未測定', (
    tester,
  ) async {
    await openScan(tester);
    expect(find.textContaining('診断目的ではありません'), findsOneWidget);
    await tester.tap(find.text('開始'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '開始'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '開始'))
          .onPressed,
      isNull,
    );
    scan.emit(
      const ScanProgress(
        phase: ScanPhase.measuring,
        elapsed: Duration(seconds: 5),
      ),
    );
    await tester.pump();
    expect(find.textContaining('残り 10 秒'), findsOneWidget);
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '結果'), findsOneWidget);
    expect(await repo.findById('rec-1'), isNotNull);
    expect(find.text('未測定'), findsWidgets);
    expect(find.text('15.2 秒'), findsOneWidget);
    expect(find.text('良好'), findsOneWidget);
    expect(find.text('レポートは未生成です。'), findsOneWidget);
    expect(find.text('体温はカメラで測定していません'), findsOneWidget);
    expect(scan.disposes, 1);
    await tester.ensureVisible(find.text('ホームへ'));
    await tester.tap(find.text('ホームへ'));
    await tester.pumpAndSettle();
    expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
  });

  testWidgets('insert failure: no navigation, honest message, retry saves', (
    tester,
  ) async {
    repo.failInsert = true;
    await openScan(tester);
    await startAndFinish(tester, successOutcome());
    expect(find.widgetWithText(AppBar, '15秒チェック'), findsOneWidget);
    expect(find.textContaining('結果は保存されていません'), findsOneWidget);
    expect(find.text('保存を再試行'), findsOneWidget);
    expect(await repo.findById('rec-1'), isNull);
    repo.failInsert = false;
    await tester.tap(find.text('保存を再試行'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '結果'), findsOneWidget);
    expect(await repo.findById('rec-1'), isNotNull);
  });

  for (final entry in {
    ScanFailureReason.permissionDenied: '設定アプリから許可してください',
    ScanFailureReason.faceNotFound: '位置を調整',
    ScanFailureReason.poorQuality: '明るい場所',
    ScanFailureReason.interrupted: '計測が中断されました',
    ScanFailureReason.cameraUnavailable: '技術的な失敗',
    ScanFailureReason.processingFailed: '技術的な失敗',
  }.entries) {
    testWidgets('failure ${entry.key.name}: message, retry, nothing saved', (
      tester,
    ) async {
      await openScan(tester);
      await startAndFinish(
        tester,
        ScanFailure(reason: entry.key, elapsed: Duration.zero),
      );
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      expect(await db.select(db.healthRecords).get(), isEmpty);
      await tester.tap(find.text('再試行'));
      await tester.pump();
      expect(scan.starts, 2);
    });
  }

  testWidgets(
    'back during scan cancels; unmount disposes; stale result ignored',
    (tester) async {
      await openScan(tester);
      await tester.tap(find.text('開始'));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(scan.cancels, greaterThanOrEqualTo(1));
      expect(scan.disposes, 1);
      expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
      scan.finish(successOutcome('late'));
      await tester.pumpAndSettle();
      expect(await repo.findById('late'), isNull);
      expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
    },
  );

  testWidgets(
    'result: self condition and temperature persist; failure shown; unknown id',
    (tester) async {
      await openScan(tester);
      await startAndFinish(tester, successOutcome());
      await tester.tap(find.text('4'));
      await tester.pump();
      repo.failUpdate = true;
      await tester.tap(find.text('体調を保存'));
      await tester.pumpAndSettle();
      expect(find.textContaining('体調を保存できませんでした'), findsOneWidget);
      expect((await repo.findById('rec-1'))!.selfCondition, isNull);
      repo.failUpdate = false;
      await tester.tap(find.text('体調を保存'));
      await tester.pumpAndSettle();
      expect(find.text('体調を保存しました'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '36.5');
      await tester.pump();
      await tester.ensureVisible(find.text('体温を保存'));
      await tester.tap(find.text('体温を保存'));
      await tester.pumpAndSettle();
      expect(find.text('体温を保存しました'), findsOneWidget);
      final saved = (await repo.findById('rec-1'))!;
      expect(saved.selfCondition, 4);
      expect(saved.bodyTemperatureC, 36.5);
      expect(saved.temperatureSource, TemperatureSource.manual);
    },
  );

  testWidgets('result with unknown id shows not-found', (tester) async {
    await openScan(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushReplacementNamed('/result', arguments: 'nope');
    await tester.pumpAndSettle();
    expect(find.text('該当する記録が見つかりません。'), findsOneWidget);
  });
}
