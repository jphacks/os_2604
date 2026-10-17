import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/history_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import 'package:os_2604/services/settings/reminder_settings_store.dart';

import '../support/fake_reminder.dart';
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
  late FakeReminderService reminder;
  late FakeReminderStore reminderStore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = _Failing(db);
    reminder = FakeReminderService();
    reminderStore = FakeReminderStore();
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
        reminderService: reminder,
        reminderStore: reminderStore,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(store: repo, now: () => now),
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
      expect(find.text('測定記録はまだありません。'), findsOneWidget);
      expect(find.text('基準値蓄積中（有効記録 0/3件）'), findsOneWidget);
    });

    tw('newest first, 未入力 for nulls', (tester) async {
      await repo.insert(_rec('old', DateTime(2026, 10, 15, 8), cond: 3));
      await repo.insert(_rec('new', DateTime(2026, 10, 16, 8), temp: 36.5));
      await pumpHistory(tester);
      expect(
        tester.getTopLeft(find.text('2026/10/16 08:00')).dy,
        lessThan(tester.getTopLeft(find.text('2026/10/15 08:00')).dy),
      );
      expect(find.textContaining('体調：未入力'), findsOneWidget);
      expect(find.textContaining('体調：3 / 5'), findsOneWidget);
    });

    tw('shows the real quality label', (tester) async {
      await repo.insert(
        _rec('p', DateTime(2026, 10, 16, 8), q: MeasurementQuality.poor),
      );
      await pumpHistory(tester);
      expect(find.textContaining('品質：不足'), findsOneWidget);
      expect(find.textContaining('品質：良好'), findsNothing);
    });

    tw('tap opens result for that id', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await repo.updateReport('a', '保存済みレポート', ReportMode.template);
      await pumpApp(tester);
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/10/16 08:00'));
      await tester.pumpAndSettle();
      // レポート済みの記録は、自己申告を挟まず結果をそのまま表示する。
      expect(find.text('10月16日（金） 8:00'), findsOneWidget);
      expect(find.text('保存済みレポート'), findsOneWidget);
    });

    tw('delete with confirm removes only that record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 15, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 16, 8)));
      await pumpHistory(tester);
      // 新しい順なので先頭（b）の削除ボタン。
      await tester.tap(find.byTooltip('この記録を削除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(await repo.findById('b'), isNull);
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('2026/10/16 08:00'), findsNothing);
    });

    tw('cancel keeps the record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await pumpHistory(tester);
      await tester.tap(find.byTooltip('この記録を削除'));
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
      await tester.tap(find.byTooltip('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('削除できませんでした'), findsOneWidget);
      expect(await repo.findById('a'), isNotNull);
    });
  });

  group('history design', () {
    tw('weekly flowers count valid days once and exclude future records', (
      tester,
    ) async {
      await repo.insert(_rec('same-1', DateTime(2026, 10, 16, 7)));
      await repo.insert(_rec('same-2', DateTime(2026, 10, 16, 8)));
      await repo.insert(
        _rec('poor', DateTime(2026, 10, 15, 8), q: MeasurementQuality.poor),
      );
      await repo.insert(_rec('future', DateTime(2026, 10, 18, 8)));
      await repo.insert(_rec('previous-week', DateTime(2026, 10, 10, 8)));
      await pumpHistory(tester);
      expect(find.text('1輪'), findsOneWidget);
      expect(find.text('今日はまだチェックしていません'), findsOneWidget);
      await repo.insert(_rec('today', DateTime(2026, 10, 17, 7)));
      await tester.pumpAndSettle();
      expect(find.text('2輪'), findsOneWidget);
      expect(find.text('今日のチェック完了'), findsOneWidget);
      await repo.deleteOne('today');
      await tester.pumpAndSettle();
      expect(find.text('1輪'), findsOneWidget);
      expect(find.text('今日はまだチェックしていません'), findsOneWidget);
    });

    tw('small screen with large text can scroll to and delete a record', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: HistoryScreen(store: repo, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      final deleteButton = find.widgetWithIcon(
        IconButton,
        Icons.delete_outline,
      );
      await tester.scrollUntilVisible(deleteButton, 160);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(await repo.findById('a'), isNull);
      expect(tester.takeException(), isNull);
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
      await repo.deleteOne('3');
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

    group('reminder', () {
      Future<void> toggle(WidgetTester tester) async {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
      }

      Switch switchOf(WidgetTester tester) =>
          tester.widget<Switch>(find.byType(Switch));

      tw('is off by default; no notification before opt-in', (tester) async {
        await openSettings(tester);
        expect(switchOf(tester).value, isFalse);
        expect(find.text('08:00'), findsOneWidget);
        expect(find.textContaining('今後追加予定'), findsNothing);
        expect(reminder.scheduled, isEmpty);
      });

      tw('enable: permission granted -> scheduled and saved', (tester) async {
        await openSettings(tester);
        await toggle(tester);
        expect(reminder.permissionRequests, 1);
        expect(reminder.scheduled, [(8, 0)]);
        expect(reminderStore.value.enabled, isTrue);
        expect(switchOf(tester).value, isTrue);
        expect(find.text('毎朝 08:00 にお知らせします'), findsOneWidget);
      });

      tw('enable: permission denied stays off and saves nothing', (
        tester,
      ) async {
        reminder.grant = false;
        await openSettings(tester);
        await toggle(tester);
        expect(find.text('通知が許可されていません。設定アプリから許可できます。'), findsOneWidget);
        expect(switchOf(tester).value, isFalse);
        expect(reminder.scheduled, isEmpty);
        expect(reminderStore.saves, 0);
      });

      tw('enable: scheduling failure is shown and not saved', (tester) async {
        reminder.failSchedule = true;
        await openSettings(tester);
        await toggle(tester);
        expect(find.textContaining('通知を設定できませんでした'), findsOneWidget);
        expect(switchOf(tester).value, isFalse);
        expect(reminderStore.saves, 0);
      });

      tw('change time reschedules and saves', (tester) async {
        reminderStore.value = const ReminderSettings(
          enabled: true,
          hour: 7,
          minute: 30,
        );
        await openSettings(tester);
        expect(find.text('07:30'), findsOneWidget);
        await tester.tap(find.text('通知時刻'));
        await tester.pumpAndSettle();
        // ダイヤル表示のまま OK で確定すると、現在の時刻が選ばれる。
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(reminder.scheduled, [(7, 30)]);
        expect(reminder.permissionRequests, 0);
        expect(reminderStore.saves, 1);
      });

      tw('change time to a new value', (tester) async {
        reminderStore.value = const ReminderSettings(enabled: true);
        await openSettings(tester);
        await tester.tap(find.text('通知時刻'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '6');
        await tester.enterText(fields.at(1), '45');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(reminder.scheduled, [(6, 45)]);
        expect(reminderStore.value.hour, 6);
        expect(reminderStore.value.minute, 45);
        expect(find.text('06:45'), findsOneWidget);
      });

      tw('disable cancels and saves', (tester) async {
        reminderStore.value = const ReminderSettings(enabled: true);
        await openSettings(tester);
        await toggle(tester);
        expect(reminder.cancels, 1);
        expect(reminderStore.value.enabled, isFalse);
        expect(switchOf(tester).value, isFalse);
      });
    });
  });
}
