import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/history_detail_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

import '../support/history_records.dart';

void main() {
  late AppDatabase db;
  late HealthRecordRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
  });
  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryDetailScreen(store: repo, recordId: id),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, tooltip == '古い記録' ? '前の日' : '次の日'),
          )
          .onPressed !=
      null;

  historyTest('shows date, quality, values and 未入力 for null', (tester) async {
    await repo.insert(historyRec('a', DateTime(2026, 10, 16, 7, 12)));
    await open(tester, 'a');
    expect(find.text('7:12 に記録'), findsOneWidget);
    expect(find.text('10月16日（金）'), findsOneWidget);
    expect(find.text('計測品質'), findsOneWidget);
    expect(find.text('良好'), findsOneWidget);
    expect(find.text('この日の記録'), findsOneWidget);
    expect(find.text('未入力'), findsNWidgets(2)); // 体調・体温
    expect(find.text('推定心拍'), findsNothing);
    expect(find.textContaining('普段'), findsNothing);
    expect(find.text('この日のレポート'), findsOneWidget);
    expect(find.text('レポートは未作成です'), findsOneWidget);
  });

  historyTest('shows entered values, heart rate reference and report', (
    tester,
  ) async {
    await repo.insert(
      historyRec(
        'a',
        DateTime(2026, 10, 16, 7, 12),
        cond: 4,
        temp: 36.4,
        hr: 66,
      ),
    );
    await repo.updateReport('a', '保存済みレポート', ReportMode.template);
    await open(tester, 'a');
    expect(find.text('4 / 5 良い'), findsOneWidget);
    expect(find.text('36.4℃'), findsOneWidget);
    expect(find.text('体温計（手入力）'), findsOneWidget);
    expect(find.text('推定心拍'), findsOneWidget);
    expect(find.text('参考値'), findsOneWidget);
    expect(find.text('66 bpm'), findsOneWidget);
    expect(find.text('定型文'), findsOneWidget);
    expect(find.text('保存済みレポート'), findsOneWidget);
  });

  historyTest('heart rate is hidden when quality is not good', (tester) async {
    await repo.insert(
      historyRec(
        'a',
        DateTime(2026, 10, 16, 7, 12),
        hr: 66,
        q: MeasurementQuality.poor,
      ),
    );
    await open(tester, 'a');
    expect(find.text('不足'), findsOneWidget);
    expect(find.text('推定心拍'), findsNothing);
  });

  historyTest('comparison uses the real baseline before that day only', (
    tester,
  ) async {
    // 基準値の期間は「その日を除く直近7日」。中央値は 3。
    await repo.insert(historyRec('b1', DateTime(2026, 10, 13, 8), cond: 2));
    await repo.insert(historyRec('b2', DateTime(2026, 10, 14, 8), cond: 3));
    await repo.insert(historyRec('b3', DateTime(2026, 10, 15, 8), cond: 4));
    await repo.insert(historyRec('day', DateTime(2026, 10, 16, 8), cond: 4));
    // その日以降の記録は基準値に入らない。
    await repo.insert(historyRec('after', DateTime(2026, 10, 17, 8), cond: 5));
    await open(tester, 'day');
    expect(find.text('普段より +1'), findsOneWidget);
    // 3件そろう前の日は比較を出さない。
    await tester.pumpWidget(const SizedBox());
    await open(tester, 'b2');
    expect(find.textContaining('普段'), findsNothing);
  });

  historyTest('prev/next move between records and disable at the ends', (
    tester,
  ) async {
    await repo.insert(historyRec('a', DateTime(2026, 10, 14, 8)));
    await repo.insert(historyRec('b', DateTime(2026, 10, 15, 8)));
    await repo.insert(historyRec('c', DateTime(2026, 10, 16, 8)));
    await open(tester, 'b');
    expect(find.text('10月15日（木）'), findsOneWidget);
    expect(enabled(tester, '古い記録'), isTrue);
    expect(enabled(tester, '新しい記録'), isTrue);

    await tester.tap(find.byTooltip('古い記録'));
    await tester.pumpAndSettle();
    expect(find.text('10月14日（水）'), findsOneWidget);
    expect(enabled(tester, '古い記録'), isFalse);
    expect(enabled(tester, '新しい記録'), isTrue);

    await tester.tap(find.byTooltip('新しい記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新しい記録'));
    await tester.pumpAndSettle();
    expect(find.text('10月16日（金）'), findsOneWidget);
    expect(enabled(tester, '新しい記録'), isFalse);
    expect(enabled(tester, '古い記録'), isTrue);
  });

  historyTest('unknown id says the record was not found', (tester) async {
    await open(tester, 'missing');
    expect(find.text('該当する記録が見つかりません。'), findsOneWidget);
  });
}
