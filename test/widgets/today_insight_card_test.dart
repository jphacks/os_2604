import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/analysis/history_baseline.dart';
import 'package:os_2604/widgets/today_insight_card.dart';

void main() {
  HealthCheckResult record(int? condition, {bool good = true}) =>
      HealthCheckResult(
        id: 'insight-test',
        measuredAt: DateTime(2026, 10, 18),
        elapsed: const Duration(seconds: 15),
        faceDetected: true,
        quality: good ? MeasurementQuality.good : MeasurementQuality.poor,
        selfCondition: condition,
      );
  const baseline = HistoryBaseline(
    validRecordCount: 5,
    selfConditionCount: 4,
    selfConditionMedian: 3.5,
  );
  Future<void> open(
    WidgetTester tester,
    HealthCheckResult r,
    HistoryBaseline? b, {
    bool large = false,
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 700)
        : const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TodayInsightCard(record: r, baseline: b),
            ),
          ),
        ),
      ),
    );
  }

  String value(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(ValueKey('insight-$key'))).data!;

  testWidgets(
    'shows exact self-reported difference without health interpretation',
    (t) async {
      await open(t, record(3), baseline);
      expect(value(t, 'current'), '3 / 5');
      expect(value(t, 'median'), '3.5 / 5');
      expect(value(t, 'difference'), '-0.5');
      expect(find.text('自己申告は普段より低めです'), findsOneWidget);
      expect(find.textContaining('体調入力 4件'), findsOneWidget);
      await open(t, record(5), baseline);
      expect(value(t, 'difference'), '+1.5');
      expect(find.text('自己申告は普段より高めです'), findsOneWidget);
      await open(
        t,
        record(3),
        const HistoryBaseline(
          validRecordCount: 3,
          selfConditionCount: 3,
          selfConditionMedian: 3,
        ),
      );
      expect(value(t, 'difference'), '0');
      expect(find.text('自己申告は普段と同じです'), findsOneWidget);
    },
  );
  testWidgets('missing self-report never becomes zero or a difference', (
    t,
  ) async {
    await open(t, record(null), baseline);
    expect(value(t, 'current'), '未入力');
    expect(value(t, 'median'), '3.5 / 5');
    expect(value(t, 'difference'), '比較なし');
    expect(find.text('体調を入力すると普段と比べられます'), findsOneWidget);
  });
  testWidgets(
    'insufficient history and load failure have distinct explanations',
    (t) async {
      await open(
        t,
        record(4),
        const HistoryBaseline(
          validRecordCount: 2,
          selfConditionCount: 1,
          selfConditionMedian: null,
        ),
      );
      expect(find.text('基準値を蓄積中'), findsOneWidget);
      expect(find.textContaining('あと2件'), findsOneWidget);
      expect(value(t, 'median'), '—');
      await open(t, record(4), null);
      expect(find.text('過去の記録を読み込めませんでした'), findsOneWidget);
      expect(value(t, 'difference'), '比較なし');
      expect(find.text('基準値を蓄積中'), findsNothing);
    },
  );
  testWidgets('poor-quality record cannot show comparison even with history', (
    t,
  ) async {
    await open(t, record(4, good: false), baseline);
    expect(value(t, 'median'), '—');
    expect(value(t, 'difference'), '比較なし');
    expect(find.text('今回は比較を表示できません'), findsOneWidget);
  });
  testWidgets(
    'small screen and 200 percent text remain readable and scrollable',
    (t) async {
      await open(t, record(4), baseline, large: true);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.textContaining('健康状態の判定ではありません'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
