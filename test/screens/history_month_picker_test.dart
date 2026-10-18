import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/history_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/widgets/history_trend_view.dart';

import '../support/history_records.dart';

void main() {
  late AppDatabase db;
  late HealthRecordRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
  });
  tearDown(() => db.close());
  Future<void> open(WidgetTester t, {bool largeText = false}) async {
    t.view.physicalSize = largeText
        ? const Size(320, 640)
        : const Size(800, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await repo.insert(historyRec('oct-a', DateTime(2026, 10, 17, 8), cond: 3));
    await repo.insert(historyRec('oct-b', DateTime(2026, 10, 17, 20), cond: 4));
    await repo.insert(historyRec('sep', DateTime(2026, 9, 30, 8), cond: 2));
    await repo.insert(historyRec('leap', DateTime(2024, 2, 29, 8), cond: 5));
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: child!,
        ),
        home: HistoryScreen(store: repo, now: () => DateTime(2026, 10, 18)),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> expand(WidgetTester t) async {
    await t.tap(key('history-period-toggle'));
    await t.pumpAndSettle();
  }

  historyTest(
    'inline month grid enables recorded months; selected month and count match list and graph',
    (t) async {
      await open(t);
      expect(key('history-row-oct-a'), findsOneWidget);
      expect(key('history-row-sep'), findsNothing);
      expect(t.widget<Text>(key('history-period-count')).data, '2件');
      await expand(t);
      expect(t.widget<TextButton>(key('history-month-8')).onPressed, isNull);
      expect(t.widget<TextButton>(key('history-month-9')).onPressed, isNotNull);
      await t.tap(key('history-month-9'));
      await t.pumpAndSettle();
      expect(key('history-month-9'), findsNothing);
      expect(key('history-row-sep'), findsOneWidget);
      expect(key('history-row-oct-a'), findsNothing);
      expect(t.widget<Text>(key('history-period-count')).data, '1件');
      await t.tap(find.text('グラフ'));
      await t.pumpAndSettle();
      final graph = t.widget<HistoryTrendView>(find.byType(HistoryTrendView));
      expect(graph.period!.start, DateTime(2026, 9, 1));
      expect(graph.period!.end, DateTime(2026, 9, 30));
      expect(graph.records.map((r) => r.id), ['sep']);
      await t.tap(find.text('リスト'));
      await t.pumpAndSettle();
      expect(key('history-row-sep'), findsOneWidget);
    },
  );
  historyTest('whole year includes all months; leap month is 29 days', (
    t,
  ) async {
    await open(t);
    await expand(t);
    await t.tap(key('history-whole-year'));
    await t.pumpAndSettle();
    expect(t.widget<Text>(key('history-period-count')).data, '3件');
    expect(key('history-row-sep'), findsOneWidget);
    await expand(t);
    await t.tap(key('history-year-2024'));
    await t.pumpAndSettle();
    expect(key('history-row-leap'), findsOneWidget);
    await t.tap(key('history-month-2'));
    await t.pumpAndSettle();
    await t.tap(find.text('グラフ'));
    await t.pumpAndSettle();
    final graph = t.widget<HistoryTrendView>(find.byType(HistoryTrendView));
    expect(graph.period!.end, DateTime(2024, 2, 29));
    expect(find.byKey(const ValueKey('bar-2024-02-29')), findsOneWidget);
  });
  historyTest(
    'whole year graph renders daily records without fabricating missing days',
    (t) async {
      await open(t);
      await expand(t);
      await t.tap(key('history-whole-year'));
      await t.pumpAndSettle();
      await t.tap(find.text('グラフ'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('bar-2026-09-30')), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-2026-10-17')), findsOneWidget);
      expect(find.text('左右にスクロールして日別の記録を確認できます'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  historyTest('small phone with large text can open panel and select a month', (
    t,
  ) async {
    await open(t, largeText: true);
    await t.ensureVisible(key('history-period-toggle'));
    await t.pumpAndSettle();
    await expand(t);
    await t.ensureVisible(key('history-month-9'));
    await t.pumpAndSettle();
    await t.tap(key('history-month-9'));
    await t.pumpAndSettle();
    expect(t.widget<Text>(key('history-period-count')).data, '1件');
    expect(t.takeException(), isNull);
  });
  historyTest(
    'opening menu overlays rows without moving them; outside tap and back dismiss',
    (t) async {
      await open(t);
      final before = t.getTopLeft(key('history-row-oct-a'));
      await expand(t);
      expect(t.getTopLeft(key('history-row-oct-a')), before);
      expect(key('history-period-overlay'), findsOneWidget);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      expect(key('history-period-overlay'), findsNothing);
      expect(t.getTopLeft(key('history-row-oct-a')), before);
      await expand(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(key('history-period-overlay'), findsNothing);
      expect(key('history-row-oct-a'), findsOneWidget);
    },
  );
}
