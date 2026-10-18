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
  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await repo.insert(historyRec('old', DateTime(2025, 10, 17, 8), cond: 2));
    await repo.insert(historyRec('a', DateTime(2026, 10, 17, 8), cond: 3));
    await repo.insert(historyRec('b', DateTime(2026, 10, 17, 20), cond: 4));
    await repo.insert(historyRec('other', DateTime(2026, 10, 16, 8), cond: 5));
    await t.pumpWidget(
      MaterialApp(
        home: HistoryScreen(store: repo, now: () => DateTime(2026, 10, 18)),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('history-row-$id'));
  historyTest(
    'year filters list and graph, survives view changes, and clears',
    (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('history-year')));
      await t.pumpAndSettle();
      await t.tap(find.text('2025年').last);
      await t.pumpAndSettle();
      expect(row('old'), findsOneWidget);
      expect(row('a'), findsNothing);
      expect(find.text('検索結果：1件'), findsOneWidget);
      await t.tap(find.text('グラフ'));
      await t.pumpAndSettle();
      final graph = t.widget<HistoryTrendView>(find.byType(HistoryTrendView));
      expect(graph.records.map((r) => r.id), ['old']);
      expect(graph.now(), DateTime(2025, 10, 17, 8));
      await t.tap(find.text('リスト'));
      await t.pumpAndSettle();
      expect(row('old'), findsOneWidget);
      expect(row('a'), findsNothing);
      await t.tap(find.text('検索を解除'));
      await t.pumpAndSettle();
      expect(row('a'), findsOneWidget);
      expect(row('old'), findsOneWidget);
    },
  );
  historyTest(
    'calendar date includes every record on that day and graphs only that day',
    (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('history-date')));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('17'),
        ),
      );
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(row('a'), findsOneWidget);
      expect(row('b'), findsOneWidget);
      expect(row('other'), findsNothing);
      expect(row('old'), findsNothing);
      expect(find.text('検索結果：2件'), findsOneWidget);
      await t.tap(find.text('グラフ'));
      await t.pumpAndSettle();
      final graph = t.widget<HistoryTrendView>(find.byType(HistoryTrendView));
      expect(graph.singleDay, isTrue);
      expect(graph.now(), DateTime(2026, 10, 17));
      expect(find.text('2026-10-17'), findsOneWidget);
      expect(find.text('1週間'), findsNothing);
    },
  );
  historyTest('no matching date shows a search-specific empty state', (
    t,
  ) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('history-date')));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('15'),
      ),
    );
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('条件に一致する記録がありません'), findsOneWidget);
    expect(find.text('検索結果：0件'), findsOneWidget);
  });
}
