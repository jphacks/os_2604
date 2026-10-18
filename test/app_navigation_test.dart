import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/widgets/camera_tab_bar.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import 'support/fake_scan.dart';
import 'support/fake_reminder.dart';

class CompletedOnboardingStore implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('history first; camera opens scan as cover; tabs and graph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: CompletedOnboardingStore(),
        repository: HealthRecordRepository(db),
        aiRunner: runnerOf(FakeAiClient()),
        reminderService: FakeReminderService(),
        reminderStore: FakeReminderStore(),
        createScanSession: () => sessionOf(FakeScanService()),
      ),
    );
    await tester.pumpAndSettle();
    int selected() =>
        tester.widget<CameraTabBar>(find.byType(CameraTabBar)).selectedIndex;
    // 起動すると履歴（5-1'）。
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
    expect(selected(), 0);
    // 5-1'：今日と今週の花は1枚のカード。ボタンではなく案内文。
    expect(find.text('今日はまだチェックしていません'), findsOneWidget);
    expect(find.text('下のカメラから15秒で記録できます'), findsOneWidget);
    expect(find.text('今日の記録を見る'), findsNothing);
    expect(find.text('今週咲いた花'), findsOneWidget);

    // カメラボタン → 3-1'（cover）。中止で下へ閉じて履歴に戻る。
    await tester.tap(find.byKey(const ValueKey('main-tab-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('顔の位置合わせ'), findsOneWidget); // 下から出てくる途中
    await tester.pumpAndSettle();
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    expect(find.text('顔の位置合わせ'), findsNothing);
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
    expect(selected(), 0);

    // 設定タブ。戻る矢印は出さない。
    await tester.tap(find.byKey(const ValueKey('main-tab-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 履歴 → 設定は左へスライド：途中では設定が右側から入ってくる。
    final settingsX = tester
        .getTopLeft(find.byKey(const ValueKey('settings-title')))
        .dx;
    expect(settingsX, greaterThan(tester.getTopLeft(find.text('履歴').first).dx));
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '履歴'), findsNothing); // 動き終われば外す
    expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(selected(), 2);

    // 設定からアプリの説明をもう一度見る（権限や通知の設定には触れない）。
    await tester.tap(find.text('アプリの説明'));
    await tester.pumpAndSettle();
    expect(find.text('タップしてはじめる'), findsNothing);
    await tester.tap(find.text('つづける'));
    await tester.pumpAndSettle();
    final close = find.text('閉じる');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-tab-0')));
    await tester.pumpAndSettle();
    expect(selected(), 0);

    // 5-1 ↔ 5-4 はスイッチより下だけ入れ替わる。履歴の見出しは残る。
    await tester.tap(find.text('グラフ'));
    await tester.pumpAndSettle();
    expect(find.text('1週間'), findsOneWidget);
    expect(find.text('今週咲いた花'), findsOneWidget);
    await tester.tap(find.text('リスト'));
    await tester.pumpAndSettle();
    expect(find.text('1週間'), findsNothing);
    expect(find.text('グラフ'), findsOneWidget);
    // スイッチを右へなぞるとグラフ、左へなぞるとリスト。
    await tester.fling(find.text('リスト'), const Offset(200, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('1週間'), findsOneWidget);
    await tester.fling(find.text('グラフ'), const Offset(-200, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('1週間'), findsNothing);
    expect(tester.takeException(), isNull);
    // drift の watch() は購読解除後に Timer を残すため、画面を外して流す。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('tapping the morning notification opens the scan directly', (
    tester,
  ) async {
    final reminder = FakeReminderService();
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: CompletedOnboardingStore(),
        repository: HealthRecordRepository(db),
        aiRunner: runnerOf(FakeAiClient()),
        reminderService: reminder,
        reminderStore: FakeReminderStore(),
        createScanSession: () => sessionOf(FakeScanService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(reminder.onOpen, isNotNull);
    reminder.onOpen!();
    await tester.pumpAndSettle();
    expect(find.text('顔の位置合わせ'), findsOneWidget);
    // 計測中にもう一度押しても重ねて開かない。
    reminder.onOpen!();
    await tester.pumpAndSettle();
    expect(find.text('顔の位置合わせ'), findsOneWidget);
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '履歴'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
