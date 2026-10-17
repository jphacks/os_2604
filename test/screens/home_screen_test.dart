import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/home_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

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
  late HealthRecordRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
  });
  tearDown(() async => db.close());

  Widget home({VoidCallback? onExplain}) => MaterialApp(
    home: HomeScreen(
      repository: repo,
      now: () => now,
      onStartCheck: () {},
      onOpenHistory: () {},
      onOpenSettings: () {},
      onShowExplanation: onExplain,
    ),
  );

  tw('記録なしは本日まだ記録がない旨を表示する', (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('本日はまだ記録がありません'), findsOneWidget);
    expect(find.text('前回結果：まだ記録がありません'), findsOneWidget);
    expect(find.textContaining('履歴未接続'), findsNothing);
  });

  tw('本日の記録があれば記録済みと前回結果を表示する', (tester) async {
    await repo.insert(
      HealthCheckResult(
        id: 'a',
        measuredAt: DateTime(2026, 10, 17, 7, 5),
        elapsed: const Duration(seconds: 15),
        faceDetected: true,
        quality: MeasurementQuality.good,
        selfCondition: 4,
      ),
    );
    await repo.insert(
      HealthCheckResult(
        id: 'b',
        measuredAt: DateTime(2026, 10, 16, 8),
        elapsed: const Duration(seconds: 15),
        faceDetected: true,
        quality: MeasurementQuality.good,
      ),
    );
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('本日は記録済み'), findsOneWidget);
    expect(find.text('前回結果：2026/10/17 07:05　品質：良好　体調：4 / 5'), findsOneWidget);
  });

  tw('昨日の記録だけなら本日はまだ・体調未測定を表示する', (tester) async {
    await repo.insert(
      HealthCheckResult(
        id: 'b',
        measuredAt: DateTime(2026, 10, 16, 8),
        elapsed: const Duration(seconds: 15),
        faceDetected: true,
        quality: MeasurementQuality.good,
      ),
    );
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('本日はまだ記録がありません'), findsOneWidget);
    expect(find.textContaining('体調：未測定'), findsOneWidget);
  });

  tw('実状態を表示し、各導線を対応するcallbackへ通知する', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: repo,
          onStartCheck: () => calls.add('start'),
          onOpenHistory: () => calls.add('history'),
          onOpenSettings: () => calls.add('settings'),
          onShowExplanation: () => calls.add('explanation'),
        ),
      ),
    );
    expect(find.textContaining('履歴未接続'), findsNothing);
    expect(find.textContaining('計測・保存サービスは未接続'), findsNothing);
    expect(find.text('本日未実施'), findsNothing);
    for (final label in ['チェック開始', '履歴', '設定', 'アプリの説明']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(calls, ['start', 'history', 'settings', 'explanation']);
  });

  tw('説明callback省略時は説明導線を表示しない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: repo,
          onStartCheck: () {},
          onOpenHistory: () {},
          onOpenSettings: () {},
        ),
      ),
    );
    expect(find.text('アプリの説明'), findsNothing);
  });

  tw('小画面と大きい文字でも最後の導線を操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HomeScreen(
          repository: repo,
          onStartCheck: () {},
          onOpenHistory: () {},
          onOpenSettings: () => opened = true,
        ),
      ),
    );
    await tester.ensureVisible(find.text('設定'));
    await tester.tap(find.text('設定'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
