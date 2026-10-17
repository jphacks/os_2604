import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/ui/asakao_style.dart';
import 'package:os_2604/ui/asakao_widgets.dart';

Future<void> _pump(WidgetTester t, Widget child) => t.pumpWidget(
  MaterialApp(
    theme: asakaoTheme(),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('quality chip shows the shared label for every quality', (
    t,
  ) async {
    for (final (q, label) in [
      (MeasurementQuality.good, '良好'),
      (MeasurementQuality.poor, '不足'),
      (MeasurementQuality.interrupted, '中断'),
    ]) {
      await _pump(t, AsakaoQualityChip(q));
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('primary button taps when enabled and ignores taps when null', (
    t,
  ) async {
    var taps = 0;
    await _pump(t, AsakaoPrimaryButton(label: 'つづける', onPressed: () => taps++));
    await t.tap(find.text('つづける'));
    expect(taps, 1);

    await _pump(t, const AsakaoPrimaryButton(label: 'つづける', onPressed: null));
    await t.tap(find.text('つづける'), warnIfMissed: false);
    expect(taps, 1);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('list row renders title, value and chevron', (t) async {
    await _pump(t, const AsakaoListRow(title: '毎朝の通知', value: '7:00'));
    expect(find.text('毎朝の通知'), findsOneWidget);
    expect(find.text('7:00'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('mascot builds for every mood', (t) async {
    for (final m in AsakaoMascotMood.values) {
      await _pump(t, AsakaoMascot(mood: m));
      expect(find.byType(AsakaoMascot), findsOneWidget);
    }
  });

  testWidgets('numbered steps and dots build', (t) async {
    await _pump(
      t,
      const Column(
        children: [
          AsakaoNumberedSteps(title: '手順', steps: ['a', 'b', 'c']),
          AsakaoStepDots(count: 3, index: 1),
        ],
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('2 / 3 ページ'), findsOneWidget);
  });
}
