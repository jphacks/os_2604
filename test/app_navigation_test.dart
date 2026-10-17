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

  testWidgets('home opens scan, history, settings and explanation', (
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
    expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
    expect(find.text('顔の位置合わせ'), findsOneWidget);
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    for (final (index, title) in [(0, '履歴'), (2, '設定')]) {
      await tester.tap(find.byKey(ValueKey('main-tab-$index')));
      await tester.pumpAndSettle();
      expect(
        index == 2
            ? find.byKey(const ValueKey('settings-title'))
            : find.widgetWithText(AppBar, title),
        findsOneWidget,
      );
      expect(find.text('未実装の画面です。今後、担当機能を接続します。'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(
        tester.widget<CameraTabBar>(find.byType(CameraTabBar)).selectedIndex,
        index,
      );
      await tester.tap(find.byKey(const ValueKey('main-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
      expect(
        tester.widget<CameraTabBar>(find.byType(CameraTabBar)).selectedIndex,
        1,
      );
    }
    await tester.ensureVisible(find.text('アプリの説明'));
    await tester.tap(find.text('アプリの説明'));
    await tester.pumpAndSettle();
    // 再表示は説明だけ（権限や設定には触れない）。
    expect(find.text('タップしてはじめる'), findsNothing);
    await tester.tap(find.text('つづける'));
    await tester.pumpAndSettle();
    final close = find.text('閉じる');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // drift の watch() は購読解除後に Timer を残すため、画面を外して流す。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
