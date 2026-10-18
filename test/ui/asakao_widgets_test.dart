import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/ui/asakao_flower.dart';
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

  testWidgets('today bud blooms only once the history is visible', (t) async {
    Iterable<AsakaoFlowerState> shown() => t
        .widgetList<AsakaoDayFlower>(find.byType(AsakaoDayFlower))
        .map((f) => f.state);
    Future<void> show({required bool bloomed, required bool visible}) =>
        _pump(t, AsakaoTodayBloom(bloomed: bloomed, visible: visible));

    await show(bloomed: false, visible: true);
    expect(shown(), [AsakaoFlowerState.todayBud]);
    // 計測の画面に隠れている間に記録された：まだ咲かせない。
    await show(bloomed: true, visible: false);
    await t.pumpAndSettle();
    expect(shown(), [AsakaoFlowerState.todayBud]);
    // 履歴が見えたら、少し待ってからつぼみが花に開く。
    await show(bloomed: true, visible: true);
    // つぼみがふくらんでから（約1秒後）花が開く。全体で約3.2秒。
    await t.pump(const Duration(milliseconds: 700));
    expect(shown(), [AsakaoFlowerState.todayBud]);
    await t.pump(const Duration(milliseconds: 800));
    expect(shown(), contains(AsakaoFlowerState.bloomed));
    await t.pumpAndSettle();
    expect(shown(), [AsakaoFlowerState.bloomed]);
  });

  testWidgets('already bloomed today shows the flower without animating', (
    t,
  ) async {
    await _pump(t, const AsakaoTodayBloom(bloomed: true, visible: true));
    // 最初のフレームから花だけ（つぼみからの切り替えを見せない）。
    expect(
      t.widget<AsakaoDayFlower>(find.byType(AsakaoDayFlower)).state,
      AsakaoFlowerState.bloomed,
    );
  });

  testWidgets('blooming dims everything except today and blocks taps', (
    t,
  ) async {
    var taps = 0;
    Future<void> show({required bool bloomed}) => _pump(
      t,
      Column(
        children: [
          const SizedBox(height: 200),
          AsakaoTodayBloom(bloomed: bloomed, visible: true),
          TextButton(onPressed: () => taps++, child: const Text('下の操作')),
        ],
      ),
    );
    final scrim = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_SpotlightPainter',
    );
    await show(bloomed: false);
    await show(bloomed: true);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(scrim, findsOneWidget);
    final stopped = <SoundEffect>[];
    SoundEffects.debugOnStop = stopped.add;
    addTearDown(() => SoundEffects.debugOnStop = null);
    // 暗い間のタップは下の画面へ通さず、解除に使う（花はすぐ咲ききる）。
    await t.tap(find.text('下の操作'), warnIfMissed: false);
    expect(taps, 0);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(scrim, findsNothing);
    expect(stopped, [SoundEffect.bloom]); // 効果音も止める
    expect(
      t
          .widgetList<AsakaoDayFlower>(find.byType(AsakaoDayFlower))
          .map((f) => f.state),
      contains(AsakaoFlowerState.bloomed),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('下の操作'));
    expect(taps, 1);
  });

  testWidgets('without a tap the dim ends by itself in about 3.4 seconds', (
    t,
  ) async {
    Future<void> show({required bool bloomed}) =>
        _pump(t, AsakaoTodayBloom(bloomed: bloomed, visible: true));
    final scrim = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_SpotlightPainter',
    );
    await show(bloomed: false);
    await show(bloomed: true);
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(scrim, findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    expect(scrim, findsNothing);
  });

  testWidgets('list row values sit at the right, next to the arrow', (t) async {
    await _pump(
      t,
      const AsakaoListRow(title: '毎朝の通知', value: '7:00', inset: 20),
    );
    final value = t.getRect(find.text('7:00'));
    final arrow = t.getRect(find.byIcon(Icons.chevron_right));
    // 値の右端は矢印のすぐ左（間は余白 6px だけ）。真ん中に浮かない。
    expect(arrow.left - value.right, lessThanOrEqualTo(8));
    expect(value.left, greaterThan(t.getRect(find.text('毎朝の通知')).right));
  });
}
