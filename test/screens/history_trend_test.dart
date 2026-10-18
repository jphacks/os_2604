import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/history_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/widgets/history_trend_view.dart';

import '../support/history_records.dart';

void main() {
  // 2026-10-17(土) 9:00。1週間は 10/11〜10/17、1か月は 9/18〜10/17。
  final now = DateTime(2026, 10, 17, 9);
  late AppDatabase db;
  late HealthRecordRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
  });
  tearDown(() async => db.close());

  Future<void> openGraph(WidgetTester tester, {bool screen = false}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: screen
            ? HistoryScreen(store: repo, now: () => now)
            : Scaffold(
                body: SingleChildScrollView(
                  child: HistoryTrendView(
                    records: await repo.loadAll(),
                    now: () => now,
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
    if (screen) {
      await tester.tap(find.text('グラフ'));
      await tester.pumpAndSettle();
    }
  }

  Finder keyed(String prefix) => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith(prefix);
  });

  Future<void> seedWeek() async {
    // 10/11 記録なし、10/13 の隣の 10/14 も記録なし。
    await repo.insert(historyRec('d12', DateTime(2026, 10, 12, 8), cond: 4));
    await repo.insert(historyRec('d13', DateTime(2026, 10, 13, 8), cond: 2));
    await repo.insert(historyRec('d15', DateTime(2026, 10, 15, 8), cond: 3));
    await repo.insert(historyRec('d16', DateTime(2026, 10, 16, 8), cond: 4));
    await repo.insert(historyRec('d17', DateTime(2026, 10, 17, 8), cond: 4));
  }

  String average(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('condition-average')))
      .data!;

  historyTest('toggle switches between list and graph', (tester) async {
    await repo.insert(historyRec('a', DateTime(2026, 10, 16, 8), cond: 4));
    await openGraph(tester, screen: true);
    expect(find.byKey(const ValueKey('history-row-a')), findsNothing);
    expect(find.text('2026年10月'), findsOneWidget);
    expect(find.text('1週間'), findsOneWidget);
    expect(
      tester.getCenter(find.text('1週間')).dx,
      greaterThan(
        tester
            .getCenter(find.byKey(const ValueKey('history-period-toggle')))
            .dx,
      ),
    );
    await tester.tap(find.text('1週間'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('graph-week-period')), findsOneWidget);
    expect(find.text('破線は記録のない日'), findsOneWidget);
    await tester.tap(find.text('リスト'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-row-a')), findsOneWidget);
    expect(find.text('破線は記録のない日'), findsNothing);
  });

  historyTest('week: bars, dashed empty days, average, x labels', (
    tester,
  ) async {
    await seedWeek();
    await openGraph(tester);
    expect(keyed('bar-'), findsNWidgets(5));
    expect(keyed('empty-'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('empty-2026-10-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-2026-10-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('bar-2026-10-17')), findsOneWidget);
    // (4+2+3+4+4)/5 = 3.4
    expect(average(tester), '3.4');
    // x 軸は日付の数字。1週間は毎日出る。
    for (final d in ['11', '12', '13', '14', '15', '16', '17']) {
      expect(
        find.descendant(
          of: find.byType(HistoryTrendView),
          matching: find.text(d),
        ),
        findsWidgets,
        reason: d,
      );
    }
  });

  historyTest('month: 30 days ending today; records outside the week count', (
    tester,
  ) async {
    await seedWeek();
    await repo.insert(historyRec('d10', DateTime(2026, 10, 10, 8), cond: 1));
    // 31日前は範囲外。
    await repo.insert(historyRec('old', DateTime(2026, 9, 17, 8), cond: 5));
    await openGraph(tester);
    expect(keyed('bar-'), findsNWidgets(5)); // 1週間には 10/10 は入らない
    await tester.tap(find.text('1か月'));
    await tester.pumpAndSettle();
    expect(keyed('bar-'), findsNWidgets(6));
    expect(keyed('empty-'), findsNWidgets(24));
    expect(find.byKey(const ValueKey('bar-2026-09-17')), findsNothing);
    expect(find.byKey(const ValueKey('empty-2026-09-18')), findsOneWidget);
    // (1+4+2+3+4+4)/6 = 3.0
    expect(average(tester), '3.0');
    await tester.tap(find.text('1週間'));
    await tester.pumpAndSettle();
    expect(keyed('bar-'), findsNWidgets(5));
  });

  historyTest('same day with several records uses the latest', (tester) async {
    await repo.insert(historyRec('am', DateTime(2026, 10, 16, 7), cond: 1));
    await repo.insert(historyRec('pm', DateTime(2026, 10, 16, 8), cond: 5));
    await openGraph(tester);
    expect(keyed('bar-'), findsOneWidget);
    expect(average(tester), '5.0');
  });

  historyTest('no records at all: all days dashed, average is a dash', (
    tester,
  ) async {
    await openGraph(tester);
    expect(keyed('bar-'), findsNothing);
    expect(keyed('empty-'), findsNWidgets(7));
    expect(average(tester), '—');
    expect(find.byKey(const ValueKey('heart-rate-empty')), findsOneWidget);
  });

  historyTest('heart-rate card says so when there is no real value', (
    tester,
  ) async {
    await seedWeek(); // 心拍なし
    await openGraph(tester);
    expect(find.text('推定心拍の記録はまだありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('heart-rate-chart')), findsNothing);
  });

  historyTest('heart-rate line has points only for real, good-quality values', (
    tester,
  ) async {
    await repo.insert(historyRec('h12', DateTime(2026, 10, 12, 8), hr: 60));
    await repo.insert(historyRec('h14', DateTime(2026, 10, 14, 8), hr: 70));
    // 品質不足の心拍と、範囲外の心拍は点にしない。
    await repo.insert(
      historyRec(
        'poor',
        DateTime(2026, 10, 16, 8),
        hr: 99,
        q: MeasurementQuality.poor,
      ),
    );
    await repo.insert(historyRec('old', DateTime(2026, 10, 1, 8), hr: 80));
    await openGraph(tester);
    expect(find.byKey(const ValueKey('heart-rate-empty')), findsNothing);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('heart-rate-chart')),
                )
                .painter!
            as TrendLinePainter;
    expect(painter.values, [null, 60, null, 70, null, null, null]);
    expect(painter.pointCount, 2);
    // 1か月にすると 10/1 の値も点になる（実値だけ）。
    await tester.tap(find.text('1か月'));
    await tester.pumpAndSettle();
    final month =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('heart-rate-chart')),
                )
                .painter!
            as TrendLinePainter;
    expect(month.values, hasLength(30));
    expect(month.pointCount, 3);
  });

  historyTest('charts expose a semantics summary', (tester) async {
    final handle = tester.ensureSemantics();
    await seedWeek();
    await repo.insert(historyRec('h12', DateTime(2026, 10, 12, 9), hr: 60));
    await repo.insert(historyRec('h14', DateTime(2026, 10, 14, 8), hr: 70));
    await openGraph(tester);
    expect(find.bySemanticsLabel('体調 1週間 平均3.4、5日分の記録'), findsOneWidget);
    expect(
      find.bySemanticsLabel('推定心拍 参考値 1週間 2日分の記録、最小60、最大70 bpm'),
      findsOneWidget,
    );
    await tester.tap(find.text('1か月'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('体調 1か月 平均3.4、5日分の記録'), findsOneWidget);
    handle.dispose();
  });
}
