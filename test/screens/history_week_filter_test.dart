import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/widgets/history_trend_view.dart';

import '../support/history_records.dart';

void main() {
  final october = DateTimeRange(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
  );
  Future<void> open(WidgetTester t, {DateTime? now, bool large = false}) async {
    t.view.physicalSize = large ? const Size(320, 900) : const Size(800, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final all = [
      historyRec('sep', DateTime(2026, 9, 30), cond: 2),
      historyRec('oct1', DateTime(2026, 10, 1), cond: 4),
      historyRec('oct5', DateTime(2026, 10, 5), cond: 5),
      historyRec('oct12', DateTime(2026, 10, 12), cond: 3),
    ];
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HistoryTrendView(
              records: all.where((r) => r.measuredAt.month == 10).toList(),
              weeklyRecords: all,
              period: october,
              now: () => now ?? DateTime(2026, 10, 18),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('1週間'));
    await t.pumpAndSettle();
  }

  Finder key(String s) => find.byKey(ValueKey(s));
  String average(WidgetTester t) =>
      t.widget<Text>(key('condition-average')).data!;
  testWidgets('seven days include records across month boundary', (t) async {
    await open(t, now: DateTime(2026, 10, 3));
    expect(find.text('2026-09-27 〜 2026-10-03'), findsOneWidget);
    expect(key('bar-2026-09-30'), findsOneWidget);
    expect(key('bar-2026-10-01'), findsOneWidget);
    expect(key('bar-2026-10-05'), findsNothing);
    expect(average(t), '3.0');
    expect(t.widget<TextButton>(key('graph-previous-week')).onPressed, isNull);
    expect(t.widget<TextButton>(key('graph-next-week')).onPressed, isNull);
    await t.tap(find.text('選択期間'));
    await t.pumpAndSettle();
    expect(key('graph-week-period'), findsNothing);
    expect(key('bar-2026-09-30'), findsNothing);
    expect(key('bar-2026-10-05'), findsOneWidget);
    expect(average(t), '4.0');
  });
  testWidgets('previous and next move by one calendar week', (t) async {
    await open(t);
    expect(find.text('2026-10-18 〜 2026-10-24'), findsOneWidget);
    expect(average(t), '—');
    expect(t.widget<TextButton>(key('graph-next-week')).onPressed, isNull);
    await t.tap(key('graph-previous-week'));
    await t.pumpAndSettle();
    expect(find.text('2026-10-11 〜 2026-10-17'), findsOneWidget);
    expect(average(t), '3.0');
    await t.tap(key('graph-previous-week'));
    await t.pumpAndSettle();
    expect(find.text('2026-10-04 〜 2026-10-10'), findsOneWidget);
    expect(average(t), '5.0');
    await t.tap(key('graph-next-week'));
    await t.pumpAndSettle();
    expect(find.text('2026-10-11 〜 2026-10-17'), findsOneWidget);
  });
  testWidgets('small screen with large text can switch and move weeks', (
    t,
  ) async {
    await open(t, large: true);
    await t.ensureVisible(key('graph-previous-week'));
    await t.tap(key('graph-previous-week'));
    await t.pumpAndSettle();
    expect(find.text('2026-10-11 〜 2026-10-17'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
