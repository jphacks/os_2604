import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  Future<void> roll(WidgetTester t, String name, int index) async {
    final picker = t.widget<CupertinoPicker>(key('history-$name-wheel'));
    picker.scrollController!.animateToItem(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
    await t.pumpAndSettle();
  }

  Future<void> apply(WidgetTester t) async {
    await t.ensureVisible(key('history-period-apply'));
    await t.pumpAndSettle();
    await t.tap(key('history-period-apply'));
    await t.pumpAndSettle();
  }

  historyTest(
    'year is left of month; selection is applied only on confirmation',
    (t) async {
      await open(t);
      await expand(t);
      expect(
        t.getCenter(key('history-year-wheel')).dx,
        lessThan(t.getCenter(key('history-month-wheel')).dx),
      );
      await roll(t, 'month', 8);
      expect(find.text('この月の記録はありません'), findsOneWidget);
      expect(
        t.widget<FilledButton>(key('history-period-apply')).onPressed,
        isNull,
      );
      await roll(t, 'month', 9);
      expect(t.widget<Text>(key('history-period-count')).data, '2件');
      expect(key('history-row-oct-a'), findsOneWidget);
      await apply(t);
      expect(key('history-period-overlay'), findsNothing);
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
  historyTest(
    'whole year includes all months; year wheel and leap month work',
    (t) async {
      await open(t);
      await expand(t);
      await roll(t, 'month', 0);
      await apply(t);
      expect(t.widget<Text>(key('history-period-count')).data, '3件');
      await expand(t);
      await roll(t, 'year', 1);
      await roll(t, 'month', 2);
      await apply(t);
      expect(key('history-row-leap'), findsOneWidget);
      await t.tap(find.text('グラフ'));
      await t.pumpAndSettle();
      final graph = t.widget<HistoryTrendView>(find.byType(HistoryTrendView));
      expect(graph.period!.end, DateTime(2024, 2, 29));
      expect(key('bar-2024-02-29'), findsOneWidget);
    },
  );
  historyTest('whole year graph keeps daily gaps and supports scrolling', (
    t,
  ) async {
    await open(t);
    await expand(t);
    await roll(t, 'month', 0);
    await apply(t);
    await t.tap(find.text('グラフ'));
    await t.pumpAndSettle();
    expect(key('bar-2026-09-30'), findsOneWidget);
    expect(key('bar-2026-10-17'), findsOneWidget);
    expect(find.text('左右にスクロールして日別の記録を確認できます'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  historyTest('small phone with large text can roll and apply', (t) async {
    await open(t, largeText: true);
    await t.ensureVisible(key('history-period-toggle'));
    await t.pumpAndSettle();
    await expand(t);
    await roll(t, 'month', 9);
    await apply(t);
    expect(t.widget<Text>(key('history-period-count')).data, '1件');
    await t.ensureVisible(find.text('グラフ'));
    await t.tap(find.text('グラフ'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('1週間'));
    await t.tap(find.text('1週間'));
    await t.pumpAndSettle();
    expect(key('graph-week-period'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  historyTest('outside tap and back discard draft without shifting records', (
    t,
  ) async {
    await open(t);
    final before = t.getTopLeft(key('history-row-oct-a'));
    await expand(t);
    expect(t.getTopLeft(key('history-row-oct-a')), before);
    await roll(t, 'month', 9);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(key('history-period-overlay'), findsNothing);
    expect(t.widget<Text>(key('history-period-count')).data, '2件');
    await expand(t);
    expect(
      t
          .widget<CupertinoPicker>(key('history-month-wheel'))
          .scrollController!
          .selectedItem,
      10,
    );
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(key('history-period-overlay'), findsNothing);
    expect(t.getTopLeft(key('history-row-oct-a')), before);
  });
}
