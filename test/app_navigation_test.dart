import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import 'support/fake_scan.dart';

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
        createScanSession: () => sessionOf(FakeScanService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '15秒チェック'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    for (final title in ['履歴', '設定']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(find.text('未実装の画面です。今後、担当機能を接続します。'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('アプリの説明'));
    await tester.tap(find.text('アプリの説明'));
    await tester.pumpAndSettle();
    final next = find.text('説明を確認して次へ');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // drift の watch() は購読解除後に Timer を残すため、画面を外して流す。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
