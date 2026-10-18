import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';

import '../support/fake_scan.dart';
import '../support/fake_reminder.dart';
import '../support/fake_led_transport.dart';

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

/// drift の watch() は購読解除後に Timer を残すため、テスト末尾で画面を外して流す。
void tw(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

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

  Future<void> openScan(
    WidgetTester tester, {
    LedNotificationService? led,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Done(),
        repository: repo,
        aiRunner: runnerOf(FakeAiClient()),
        reminderService: FakeReminderService(),
        reminderStore: FakeReminderStore(),
        createScanSession: () => sessionOf(scan),
        ledService: led,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main-tab-1'))); // カメラボタン
    await tester.pumpAndSettle();
  }

  Future<void> startAndFinish(WidgetTester tester, ScanOutcome o) async {
    await tester.pump();
    scan.finish(o);
    await tester.pumpAndSettle();
  }

  tw('success saves before the result screen; nulls are 未入力', (tester) async {
    await openScan(tester);
    expect(find.textContaining('診断目的ではありません'), findsOneWidget);
    await tester.pump();
    // 開いた瞬間に1回だけ計測を始める。開始ボタンは無い。
    expect(scan.starts, 1);
    expect(find.widgetWithText(FilledButton, '開始'), findsNothing);
    scan.emit(
      const ScanProgress(
        phase: ScanPhase.measuring,
        elapsed: Duration(seconds: 5),
      ),
    );
    await tester.pump();
    expect(find.text('計測中'), findsOneWidget);
    expect(find.text('そのまま動かずに'), findsOneWidget);
    expect(find.text('10'), findsOneWidget); // 残り秒数（Cの進捗から）
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    // 保存が先、画面は自己申告（4-1）。
    expect(find.text('計測できました'), findsOneWidget);
    expect(find.text('いまの体調は？'), findsOneWidget);
    expect(await repo.findById('rec-1'), isNotNull);
    expect(scan.disposes, 1);
    // 何も入力せずに結果へ進める。未入力は未入力と表示し、0や正常値で埋めない。
    await tester.tap(find.text('結果を見る'));
    await tester.pumpAndSettle();
    expect(find.text('今日の記録ができました'), findsOneWidget);
    expect(find.text('未入力'), findsNWidgets(2));
    expect(find.textContaining('推定心拍'), findsNothing);
    expect(find.text('良好'), findsOneWidget);
    expect(find.text('定型文'), findsOneWidget);
    expect(find.text('15.2 秒'), findsNothing);
    expect(find.textContaining('15.2 秒'), findsOneWidget);
    await tester.tap(find.text('履歴に戻る'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
  });

  tw('AI fallback and result input updates do not resend completion LED', (
    tester,
  ) async {
    final transport = FakeLedTransport();
    final led = LedNotificationService(transport);
    led.initialize();
    transport.status.add(BluetoothAvailability.ready);
    unawaited(led.connect(const LedKit('kit', 'Find Me Target')));
    await tester.pump();
    transport.links.last.add(KitLink.connected);
    await tester.pump();
    unawaited(led.testLed());
    await tester.pump();
    led.enableAutomatic(true);
    expect(led.automatic, isTrue);
    await openScan(tester, led: led);
    expect(scan.starts, 1);
    transport.writes.clear();
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(transport.writes.where((w) => w.$2 == 2), hasLength(1));
    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('結果を見る'));
    await tester.pumpAndSettle();
    expect(find.text('定型文'), findsOneWidget);
    expect((await repo.findById('rec-1'))!.selfCondition, 4);
    expect(transport.writes.where((w) => w.$2 == 2), hasLength(1));
    await tester.tap(find.text('履歴に戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-row-rec-1')));
    await tester.pumpAndSettle();
    expect(transport.writes.where((w) => w.$2 == 2), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    led.dispose();
    await tester.pump();
  });

  tw('insert failure: no navigation, honest message, retry saves', (
    tester,
  ) async {
    repo.failInsert = true;
    await openScan(tester);
    await startAndFinish(tester, successOutcome());
    expect(find.text('顔の位置合わせ'), findsOneWidget);
    expect(find.textContaining('結果は保存されていません'), findsOneWidget);
    expect(find.text('保存を再試行'), findsOneWidget);
    expect(await repo.findById('rec-1'), isNull);
    repo.failInsert = false;
    await tester.tap(find.text('保存を再試行'));
    await tester.pumpAndSettle();
    expect(find.text('計測できました'), findsOneWidget);
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
    tw('failure ${entry.key.name}: message, retry, nothing saved', (
      tester,
    ) async {
      await openScan(tester);
      await startAndFinish(
        tester,
        ScanFailure(reason: entry.key, elapsed: Duration.zero),
      );
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.text('もう一度測る'), findsOneWidget);
      expect(await db.select(db.healthRecords).get(), isEmpty);
      await tester.tap(find.text('もう一度測る'));
      await tester.pump();
      expect(scan.starts, 2);
    });
  }

  tw('back during scan cancels; unmount disposes; stale result ignored', (
    tester,
  ) async {
    await openScan(tester);
    await tester.pump();
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    expect(scan.cancels, greaterThanOrEqualTo(1));
    expect(scan.disposes, 1);
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
    scan.finish(successOutcome('late'));
    await tester.pumpAndSettle();
    expect(await repo.findById('late'), isNull);
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
  });

  tw('result: inputs persist on the same record; failure shown then retried', (
    tester,
  ) async {
    await openScan(tester);
    await startAndFinish(tester, successOutcome());
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '36.5');
    await tester.pump();
    repo.failUpdate = true;
    await tester.tap(find.text('結果を見る'));
    await tester.pumpAndSettle();
    expect(find.textContaining('入力を保存できませんでした'), findsOneWidget);
    expect(find.text('いまの体調は？'), findsOneWidget); // 入力画面に留まる
    expect((await repo.findById('rec-1'))!.selfCondition, isNull);
    repo.failUpdate = false;
    await tester.tap(find.text('結果を見る'));
    await tester.pumpAndSettle();
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.selfCondition, 4);
    expect(saved.bodyTemperatureC, 36.5);
    expect(saved.temperatureSource, TemperatureSource.manual);
    expect(saved.reportText, isNotNull);
    expect(find.text('4 / 5 良い'), findsOneWidget);
    expect(find.text('36.5℃'), findsOneWidget);
  });

  tw('result with unknown id shows not-found', (tester) async {
    await openScan(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushReplacementNamed('/result', arguments: 'nope');
    await tester.pumpAndSettle();
    expect(find.text('該当する記録が見つかりません。'), findsOneWidget);
  });
}
