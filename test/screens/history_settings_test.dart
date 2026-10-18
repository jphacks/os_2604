import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/settings_screen.dart';
import 'package:os_2604/services/settings/feedback_settings_store.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/history_detail_screen.dart';
import 'package:os_2604/screens/history_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import 'package:os_2604/services/settings/reminder_settings_store.dart';

import 'package:os_2604/ui/asakao_flower.dart';
import 'package:os_2604/ui/asakao_widgets.dart';

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

class _FeedbackStore implements FeedbackSettingsStore {
  FeedbackSettings value = const FeedbackSettings();
  bool fail = false;
  @override
  Future<FeedbackSettings> load() async => value;
  @override
  Future<void> save(FeedbackSettings settings) async {
    if (fail) throw StateError('save failed');
    value = settings;
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

  /// 縦に長い画面で履歴を開く（詳細へも進める）。今日は [now]。
  Future<void> pumpTallHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.historyDetail: (context) => HistoryDetailScreen(
            store: repo,
            recordId: ModalRoute.of(context)!.settings.arguments as String?,
          ),
        },
        home: HistoryScreen(store: repo, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('history', () {
    tw('empty state', (tester) async {
      await pumpHistory(tester);
      expect(find.text('まだ記録がありません'), findsOneWidget);
      expect(find.text('基準値蓄積中（有効記録 0/3件）'), findsOneWidget);
      // 記録がなくても前の週へさかのぼれる。
      await tester.tap(find.byTooltip('前の週'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('week-title'))).data,
        '先週咲いた花',
      );
    });

    Finder row(String id) => find.byKey(ValueKey('history-row-$id'));

    tw('newest first, 未入力 for nulls', (tester) async {
      await repo.insert(_rec('old', DateTime(2026, 10, 15, 8), cond: 3));
      await repo.insert(_rec('new', DateTime(2026, 10, 16, 8), temp: 36.5));
      await pumpHistory(tester);
      expect(
        tester.getTopLeft(row('new')).dy,
        lessThan(tester.getTopLeft(row('old')).dy),
      );
      // 行の中身：日付の数字・曜日・時刻、体調（未入力は「未入力」）。
      expect(
        find.descendant(of: row('new'), matching: find.text('16')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('new'), matching: find.text('金')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('new'), matching: find.text('8:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('new'), matching: find.text('未入力')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('old'), matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.text('2026年10月'), findsOneWidget);
    });

    tw('shows the real quality label', (tester) async {
      await repo.insert(
        _rec('p', DateTime(2026, 10, 16, 8), q: MeasurementQuality.poor),
      );
      await pumpHistory(tester);
      expect(
        find.descendant(of: row('p'), matching: find.text('不足')),
        findsOneWidget,
      );
      expect(find.text('良好'), findsNothing);
    });

    tw('tap opens the detail for that id', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await repo.updateReport('a', '保存済みレポート', ReportMode.template);
      await pumpApp(tester); // 起動すると履歴（5-1）
      await tester.tap(row('a'));
      await tester.pumpAndSettle();
      expect(find.text('8:00 に記録'), findsOneWidget);
      expect(find.text('10月16日（金）'), findsOneWidget);
      expect(find.text('保存済みレポート'), findsOneWidget);
    });

    Future<void> openDetailFromApp(WidgetTester tester, String id) async {
      await pumpApp(tester); // 起動すると履歴（5-1）
      await tester.tap(row(id));
      await tester.pumpAndSettle();
    }

    tw('delete with confirm removes only that record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 15, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 16, 8)));
      await openDetailFromApp(tester, 'b');
      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(await repo.findById('b'), isNull);
      expect(await repo.findById('a'), isNotNull);
      // 詳細は閉じて履歴に戻り、削除した行だけ消える。
      expect(row('b'), findsNothing);
      expect(row('a'), findsOneWidget);
    });

    tw('cancel keeps the record', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await openDetailFromApp(tester, 'a');
      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('10月16日（金）'), findsOneWidget);
    });

    tw('delete failure is shown as failure', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      repo.fail = true;
      await openDetailFromApp(tester, 'a');
      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('削除できませんでした'), findsOneWidget);
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('10月16日（金）'), findsOneWidget);
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
      // 「N輪」の表示はやめたので、咲いた花の数で数える。
      int bloomed() => tester
          .widgetList<AsakaoDayFlower>(find.byType(AsakaoDayFlower))
          .where((f) => f.state == AsakaoFlowerState.bloomed)
          .length;
      await pumpHistory(tester);
      expect(find.textContaining('輪'), findsNothing);
      expect(bloomed(), 1);
      expect(find.text('今日はまだチェックしていません'), findsOneWidget);
      await repo.insert(_rec('today', DateTime(2026, 10, 17, 7)));
      await tester.pumpAndSettle();
      expect(bloomed(), 2);
      expect(find.text('今日のチェック完了'), findsOneWidget);
      await repo.deleteOne('today');
      await tester.pumpAndSettle();
      expect(bloomed(), 1);
      expect(find.text('今日はまだチェックしていません'), findsOneWidget);
    });

    tw('past weeks: arrows and swipe move weeks; a day opens its record', (
      tester,
    ) async {
      // 今日は 2026-10-17（土）。先週は 10/4〜10/10。
      await repo.insert(_rec('last-week', DateTime(2026, 10, 7, 8)));
      await repo.insert(_rec('two-weeks', DateTime(2026, 9, 30, 8)));
      await pumpTallHistory(tester);
      String? title() =>
          tester.widget<Text>(find.byKey(const ValueKey('week-title'))).data;
      expect(title(), '今週咲いた花');
      // 曜日の下に日付（今週は 10/11〜10/17）。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('week-day-10-17')),
          matching: find.text('17'),
        ),
        findsOneWidget,
      );
      // 見出しの上で右へなぞっても前の週へ、左へなぞると戻る。
      await tester.fling(
        find.byKey(const ValueKey('week-title')),
        const Offset(200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(title(), '先週咲いた花');
      await tester.fling(
        find.byKey(const ValueKey('week-title')),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(title(), '今週咲いた花');
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right).first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('前の週'));
      await tester.pumpAndSettle();
      expect(title(), '先週咲いた花');
      // 右へスワイプでさらに前の週（記録がある一番古い週まで）。
      await tester.fling(
        find.byKey(const ValueKey('week-day-10-7')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(title(), '9月27日〜10月3日に咲いた花');
      // 記録より前の週（アプリを入れる前）にもさかのぼれる。
      await tester.tap(find.byTooltip('前の週'));
      await tester.pumpAndSettle();
      expect(title(), '9月20日〜9月26日に咲いた花');
      expect(
        tester
            .widgetList<AsakaoDayFlower>(find.byType(AsakaoDayFlower))
            .where((f) => f.state == AsakaoFlowerState.bloomed),
        isEmpty,
      );
      await tester.tap(find.byTooltip('次の週'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('次の週'));
      await tester.pumpAndSettle();
      expect(title(), '先週咲いた花');
      // 記録のある日を押すと、その日の詳細へ。
      await tester.tap(find.byKey(const ValueKey('week-day-10-7')));
      await tester.pumpAndSettle();
      expect(find.text('10月7日（水）'), findsOneWidget);
    });

    tw('swipe left on a row deletes it after confirming; cancel keeps it', (
      tester,
    ) async {
      Finder row(String id) => find.byKey(ValueKey('history-row-$id'));
      await repo.insert(_rec('a', DateTime(2026, 10, 15, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 16, 8)));
      await pumpTallHistory(tester);
      await tester.drag(row('a'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await confirm(tester, 'キャンセル');
      expect(row('a'), findsOneWidget);
      expect(await repo.findById('a'), isNotNull);
      await tester.drag(row('a'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      // 背景にも「削除」が出ているので、確認ダイアログのボタンを押す。
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(row('a'), findsNothing);
      expect(await repo.findById('a'), isNull);
      expect(await repo.findById('b'), isNotNull);
    });

    tw('swipe delete failure keeps the row and says so', (tester) async {
      Finder row(String id) => find.byKey(ValueKey('history-row-$id'));
      await repo.insert(_rec('a', DateTime(2026, 10, 15, 8)));
      repo.fail = true;
      await pumpTallHistory(tester);
      await tester.drag(row('a'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      // 背景にも「削除」が出ているので、確認ダイアログのボタンを押す。
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(row('a'), findsOneWidget);
      expect(find.text('削除できませんでした。再試行してください。'), findsOneWidget);
    });

    tw('small screen with large text can open and delete a record', (
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
          routes: {
            AppRoutes.historyDetail: (_) =>
                HistoryDetailScreen(store: repo, recordId: 'a'),
          },
          home: HistoryScreen(store: repo, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      final rowFinder = find.byKey(const ValueKey('history-row-a'));
      // 週の花も横にスクロールできるので、縦の一覧を指定する。
      await tester.scrollUntilVisible(
        rowFinder,
        160,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();
      final del = find.text('この記録を削除');
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      await tester.tap(del);
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
    tw('sound and vibration switches save and apply; failure keeps them', (
      tester,
    ) async {
      final store = _FeedbackStore();
      addTearDown(() => SoundEffects.settings = const FeedbackSettings());
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            repository: repo,
            reminderService: reminder,
            reminderStore: reminderStore,
            feedbackStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('計測'), findsOneWidget);
      Finder toggle(String title) => find.descendant(
        of: find.widgetWithText(AsakaoSwitchRow, title),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(toggle('効果音')).value, isTrue);
      await tester.tap(toggle('効果音'));
      await tester.pumpAndSettle();
      expect(store.value.sound, isFalse);
      expect(SoundEffects.settings.sound, isFalse);
      expect(tester.widget<Switch>(toggle('効果音')).value, isFalse);

      store.fail = true;
      await tester.tap(toggle('振動'));
      await tester.pumpAndSettle();
      expect(store.value.haptics, isTrue);
      expect(SoundEffects.settings.haptics, isTrue);
      expect(tester.widget<Switch>(toggle('振動')).value, isTrue);
      expect(find.text('設定を保存できませんでした（変更されていません）'), findsOneWidget);
    });

    Future<void> openSettings(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
    }

    tw('shows the sections, rows and privacy footnote', (tester) async {
      await openSettings(tester);
      expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);
      for (final text in [
        '毎日の記録',
        '毎朝の通知',
        'オフ',
        '情報',
        'このアプリについて',
        'データ',
        '記録をすべて削除',
        '画像は保存されません。記録はこの端末の中だけにあります。',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // 研究モードの保存先がないときは行も出さない。
      expect(find.textContaining('研究'), findsNothing);
      expect(find.textContaining('プライバシーポリシー'), findsNothing);
    });

    tw('reminder row shows the saved time', (tester) async {
      reminderStore.value = const ReminderSettings(
        enabled: true,
        hour: 7,
        minute: 30,
      );
      await openSettings(tester);
      expect(find.text('7:30'), findsOneWidget);
      expect(find.text('オフ'), findsNothing);
    });

    tw('about screen opens with disclaimer and data handling', (tester) async {
      await openSettings(tester);
      await tester.tap(find.text('このアプリについて'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'このアプリについて'), findsOneWidget);
      expect(find.text('あさかお'), findsOneWidget);
      expect(find.text('免責事項'), findsOneWidget);
      expect(find.textContaining('診断・治療・予防を目的としていません'), findsOneWidget);
      expect(find.textContaining('119番'), findsOneWidget);
      expect(find.textContaining('この端末の中だけに保存されます'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);
    });

    tw('delete all with confirm; onboarding is kept', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await repo.insert(_rec('b', DateTime(2026, 10, 15, 8)));
      await DriftOnboardingStore(db).completeOnboarding();
      await openSettings(tester);
      await tester.tap(find.text('記録をすべて削除'));
      await tester.pumpAndSettle();
      expect(find.text('すべての記録を削除しますか？'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget); // 6-3 は sheet
      expect(find.textContaining('取り消せません'), findsOneWidget);
      await confirm(tester, '削除する');
      expect(await repo.findInRange(DateTime(2000), DateTime(2100)), isEmpty);
      expect(find.text('記録をすべて削除しました'), findsOneWidget);
      expect(await DriftOnboardingStore(db).hasCompletedOnboarding(), isTrue);
    });

    tw('cancel keeps records', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      await openSettings(tester);
      await tester.tap(find.text('記録をすべて削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(await repo.findById('a'), isNotNull);
      expect(find.text('すべての記録を削除しますか？'), findsNothing);
      expect(find.text('記録をすべて削除しました'), findsNothing);
    });

    tw('failure is shown as failure', (tester) async {
      await repo.insert(_rec('a', DateTime(2026, 10, 16, 8)));
      repo.fail = true;
      await openSettings(tester);
      await tester.tap(find.text('記録をすべて削除'));
      await tester.pumpAndSettle();
      await confirm(tester, '削除する');
      expect(find.textContaining('削除できませんでした'), findsOneWidget);
      expect(find.text('記録をすべて削除しました'), findsNothing);
      expect(await repo.findById('a'), isNotNull);
    });

    group('reminder', () {
      Future<void> openReminder(WidgetTester tester) async {
        await openSettings(tester);
        await tester.tap(find.text('毎朝の通知'));
        await tester.pumpAndSettle();
      }

      Future<void> toggle(WidgetTester tester) async {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
      }

      Switch switchOf(WidgetTester tester) =>
          tester.widget<Switch>(find.byType(Switch));

      tw('is off by default; no notification before opt-in', (tester) async {
        await openReminder(tester);
        expect(switchOf(tester).value, isFalse);
        expect(find.text('8:00'), findsOneWidget);
        expect(find.textContaining('今後追加予定'), findsNothing);
        expect(reminder.scheduled, isEmpty);
      });

      tw('enable: permission granted -> scheduled and saved', (tester) async {
        await openReminder(tester);
        await toggle(tester);
        expect(reminder.permissionRequests, 1);
        expect(reminder.scheduled, [(8, 0)]);
        expect(reminderStore.value.enabled, isTrue);
        expect(switchOf(tester).value, isTrue);
        expect(find.text('毎朝 8:00 にお知らせします'), findsOneWidget);
      });

      tw('enable: permission denied stays off and saves nothing', (
        tester,
      ) async {
        reminder.grant = false;
        await openReminder(tester);
        await toggle(tester);
        expect(find.text('通知が許可されていません。設定アプリから許可できます。'), findsOneWidget);
        expect(switchOf(tester).value, isFalse);
        expect(reminder.scheduled, isEmpty);
        expect(reminderStore.saves, 0);
      });

      tw('enable: scheduling failure is shown and not saved', (tester) async {
        reminder.failSchedule = true;
        await openReminder(tester);
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
        await openReminder(tester);
        expect(find.text('7:30'), findsOneWidget);
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
        await openReminder(tester);
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
        expect(find.text('6:45'), findsOneWidget);
      });

      tw('disable cancels and saves', (tester) async {
        reminderStore.value = const ReminderSettings(enabled: true);
        await openReminder(tester);
        await toggle(tester);
        expect(reminder.cancels, 1);
        expect(reminderStore.value.enabled, isFalse);
        expect(switchOf(tester).value, isFalse);
      });
    });
  });
}
