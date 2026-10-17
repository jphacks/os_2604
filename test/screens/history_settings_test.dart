import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/history_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import '../support/fake_scan.dart';

class _Failing extends HealthRecordRepository {
  _Failing(super.db);
  bool fail = false;
  @override
  Future<void> delete(String id) async {
    if (fail) throw StateError('x');
    return super.delete(id);
  }

  @override
  Future<void> deleteAll() async {
    if (fail) throw StateError('x');
    return super.deleteAll();
  }
}

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

HealthCheckResult _rec(
  String id,
  DateTime at, {
  int? cond,
  double? temp,
  MeasurementQuality q = MeasurementQuality.good,
}) => HealthCheckResult(
  id: id,
  measuredAt: at,
  elapsed: const Duration(seconds: 15),
  faceDetected: true,
  quality: q,
  selfCondition: cond,
  bodyTemperatureC: temp,
  temperatureSource: temp == null
      ? TemperatureSource.none
      : TemperatureSource.manual,
);

/// drift の watch() は購読解除後に Timer を残すため、テスト末尾で画面を外して流す。
void tw(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

void main() {
  final now = DateTime(2026, 10, 17, 9);
  late AppDatabase db;
  late _Failing repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = _Failing(db);
  });
  tearDown(() async => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Done(),
        repository: repo,
        createScanSession: () => sessionOf(FakeScanService()),
        aiRunner: runnerOf(FakeAiClient()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(repository: repo, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  group('history', () {
    tw('empty state', (tester) async {
      await pumpHistory(tester);
      expect(find.text('まだ記録がありません'), findsOneWidget);
      expect(find.text('基準値蓄積中（有効記録 0/3件）'), findsOneWidget);
    });

    tw('newest first, 未測定 for nulls', (tester) async {
      await repo.insert(_rec('old', DateTime(2026, 10, 15, 8), cond: 3));
      await repo.insert(_rec('new', DateTime(2026, 10, 16, 8), temp: 36.5));
      await pumpHistory(tester);
      expect(
        tester.getTopLeft(find.text('2026/10/16 08:00')).dy,
        lessThan(tester.getTopLeft(find.text('2026/10/15 08:00')).dy),
      );
      expect(find.textContaining('体調：未測定'), findsOneWidget);
      expect(find.textContaining('体温：未測定'), findsOneWidget);
      expect(find.textContaining('体温：36.5 ℃（手入力）'), findsOneWidget);
    });

    tw('tap opens result for that id', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await pumpApp(tester);
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/10/16 08:00'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '結果'), findsOneWidget);
      expect(find.text('2026/10/16 08:00'), findsOneWidget);
    });

    tw('delete with confirm removes only that record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 15, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 16, 8)));
      await pumpHistory(tester);
      await tester.tap(find.byTooltip('2026/10/16 08:00 の記録を削除'));
      await tester.pumpAndSettle();
      await confirm(tester, '削除する');
      expect(await repo.findById('b'), isNull);
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('記録を削除しました'), findsOneWidget);
      expect(find.text('2026/10/16 08:00'), findsNothing);
    });

    tw('cancel keeps the record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await pumpHistory(tester);
      await tester.tap(find.byTooltip('2026/10/16 08:00 の記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('2026/10/16 08:00'), findsOneWidget);
    });

    tw('delete failure is shown as failure', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      repo.fail = true;
      await pumpHistory(tester);
      await tester.tap(find.byTooltip('2026/10/16 08:00 の記録を削除'));
      await tester.pumpAndSettle();
      await confirm(tester, '削除する');
      expect(find.textContaining('削除できませんでした'), findsOneWidget);
      expect(find.text('記録を削除しました'), findsNothing);
      expect(await repo.findById('a'), isNotNull);
    });
  });

  group('baseline', () {
    tw('fewer than 3 valid records in window accumulates', (tester) async {
      await repo.insert(_rec('1', DateTime(2026, 10, 16, 8), cond: 3));
      await repo.insert(_rec('2', DateTime(2026, 10, 15, 8), cond: 3));
      // Today and 8 days ago are outside the window; poor quality is invalid.
      await repo.insert(_rec('3', DateTime(2026, 10, 17, 7), cond: 3));
      await repo.insert(_rec('4', DateTime(2026, 10, 9, 8), cond: 3));
      await repo.insert(
        _rec(
          '5',
          DateTime(2026, 10, 14, 8),
          cond: 3,
          q: MeasurementQuality.poor,
        ),
      );
      await pumpHistory(tester);
      expect(find.text('基準値蓄積中（有効記録 2/3件）'), findsOneWidget);
    });

    tw('3 or more shows the median and updates on change', (tester) async {
      await repo.insert(_rec('1', DateTime(2026, 10, 16, 8), cond: 2));
      await repo.insert(_rec('2', DateTime(2026, 10, 15, 8), cond: 4));
      await repo.insert(_rec('3', DateTime(2026, 10, 10, 8), cond: 5));
      await pumpHistory(tester);
      expect(find.textContaining('中央値：4.0 / 5（有効記録 3件）'), findsOneWidget);
      await repo.delete('3');
      await tester.pumpAndSettle();
      expect(find.text('基準値蓄積中（有効記録 2/3件）'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
    }

    tw('delete all with confirm; onboarding is kept', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 15, 8)));
      await DriftOnboardingStore(db).completeOnboarding();
      await openSettings(tester);
      expect(find.text('このアプリは診断目的ではありません'), findsOneWidget);
      await tester.tap(find.text('すべての健康記録を削除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('元に戻せません'), findsOneWidget);
      await confirm(tester, '削除する');
      expect(await repo.findInRange(DateTime(2000), DateTime(2100)), isEmpty);
      expect(find.text('すべての健康記録を削除しました'), findsOneWidget);
      expect(await DriftOnboardingStore(db).hasCompletedOnboarding(), isTrue);
    });

    tw('cancel keeps records', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await openSettings(tester);
      await tester.tap(find.text('すべての健康記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('すべての健康記録を削除しました'), findsNothing);
    });

    tw('failure is shown as failure', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      repo.fail = true;
      await openSettings(tester);
      await tester.tap(find.text('すべての健康記録を削除'));
      await tester.pumpAndSettle();
      await confirm(tester, '削除する');
      expect(find.textContaining('削除できませんでした'), findsOneWidget);
      expect(find.text('すべての健康記録を削除しました'), findsNothing);
      expect(await repo.findById('a'), isNotNull);
    });
  });
}
