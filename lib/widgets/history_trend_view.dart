import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/analysis/history_trend.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// 履歴の「グラフ」表示。体調（棒）と推定心拍 参考値（折れ線）を、実際の記録だけで描く。
///
/// 期間は「今日を最後の日とする直近7日 / 30日」（カレンダー月ではない）。
/// 外部パッケージは使わず、棒は通常のウィジェット、折れ線は CustomPaint で描く。
class HistoryTrendView extends StatefulWidget {
  const HistoryTrendView({super.key, required this.records, required this.now});

  final List<HealthCheckResult> records;
  final DateTime Function() now;

  @override
  State<HistoryTrendView> createState() => _HistoryTrendViewState();
}

enum _Range {
  week('1週間', 7),
  month('1か月', 30);

  const _Range(this.label, this.days);
  final String label;
  final int days;
}

class _HistoryTrendViewState extends State<HistoryTrendView> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final days = buildDailyTrend(
      widget.records,
      today: widget.now(),
      days: _range.days,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final r in _Range.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _RangeChip(
                  label: r.label,
                  selected: r == _range,
                  onTap: () => setState(() => _range = r),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ConditionCard(days: days, rangeLabel: _range.label),
        const SizedBox(height: 12),
        _HeartRateCard(days: days, rangeLabel: _range.label),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    excludeSemantics: true,
    label: label,
    onTap: onTap,
    child: Material(
      color: selected ? AsakaoStyle.ink : AsakaoStyle.neutralBackground,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AsakaoStyle.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// x 軸の日付を出す日。1週間は毎日、1か月は今日から数えて5日おき。
bool _showDayLabel(int index, int count) =>
    count <= 7 || (count - 1 - index) % 5 == 0;

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _DayLabels extends StatelessWidget {
  const _DayLabels(this.days);
  final List<DailyTrend> days;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < days.length; i++)
        Expanded(
          child: _showDayLabel(i, days.length)
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${days[i].day.day}',
                    style: TextStyle(
                      fontSize: days.length <= 7 ? 12 : 10,
                      fontWeight: i == days.length - 1
                          ? FontWeight.w800
                          : FontWeight.normal,
                      color: AsakaoStyle.muted,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
    ],
  );
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.days, required this.rangeLabel});
  final List<DailyTrend> days;
  final String rangeLabel;

  static const _barMaxHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final avg = averageCondition(days);
    final count = days.where((d) => d.condition != null).length;
    final dense = days.length > 7;
    final summary = avg == null
        ? '体調 $rangeLabel 記録なし'
        : '体調 $rangeLabel 平均${avg.toStringAsFixed(1)}、$count日分の記録';
    return AsakaoCard(
      child: Semantics(
        container: true,
        label: summary,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Expanded(
                  child: Text(
                    '体調',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AsakaoStyle.ink,
                    ),
                  ),
                ),
                const Text('平均 ', style: AsakaoStyle.caption),
                Text(
                  avg == null ? '—' : avg.toStringAsFixed(1),
                  key: const ValueKey('condition-average'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AsakaoStyle.ink,
                  ),
                ),
                const Text(' / 5', style: AsakaoStyle.caption),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: _barMaxHeight + 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: dense ? 1 : 8,
                        ),
                        child: _bar(days[i], i == days.length - 1, dense),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _DayLabels(days),
            const SizedBox(height: 12),
            const Text('破線は記録のない日', style: AsakaoStyle.caption),
          ],
        ),
      ),
    );
  }

  Widget _bar(DailyTrend d, bool isToday, bool dense) {
    final v = d.condition;
    if (v == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: CustomPaint(
          key: ValueKey('empty-${_ymd(d.day)}'),
          size: Size(dense ? 8 : 24, dense ? 12 : 18),
          painter: _DashedBoxPainter(),
        ),
      );
    }
    return Column(
      key: ValueKey('bar-${_ymd(d.day)}'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$v',
            style: TextStyle(
              fontSize: dense ? 10 : 13,
              fontWeight: FontWeight.w800,
              color: AsakaoStyle.ink,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: _barMaxHeight * v / 5,
          decoration: BoxDecoration(
            color: isToday
                ? AsakaoStyle.link
                : AsakaoStyle.link.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(dense ? 2 : 6),
          ),
        ),
      ],
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AsakaoStyle.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(4),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 5) {
        canvas.drawPath(metric.extractPath(d, d + 2.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) => false;
}

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard({required this.days, required this.rangeLabel});
  final List<DailyTrend> days;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) d.heartRateBpm];
    final real = [for (final v in values) ?v];
    final String summary;
    if (real.isEmpty) {
      summary = '推定心拍 参考値 $rangeLabel 記録なし';
    } else {
      final lo = real.reduce((a, b) => a < b ? a : b).round();
      final hi = real.reduce((a, b) => a > b ? a : b).round();
      summary = '推定心拍 参考値 $rangeLabel ${real.length}日分の記録、最小$lo、最大$hi bpm';
    }
    return AsakaoCard(
      child: Semantics(
        container: true,
        label: summary,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  '推定心拍',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AsakaoStyle.ink,
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AsakaoStyle.neutralBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '参考値',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AsakaoStyle.muted,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text('bpm', style: AsakaoStyle.caption),
              ],
            ),
            const SizedBox(height: 12),
            if (real.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '推定心拍の記録はまだありません',
                  key: ValueKey('heart-rate-empty'),
                  style: AsakaoStyle.caption,
                ),
              )
            else ...[
              SizedBox(
                height: 110,
                child: CustomPaint(
                  key: const ValueKey('heart-rate-chart'),
                  painter: TrendLinePainter(values),
                ),
              ),
              const SizedBox(height: 6),
              _DayLabels(days),
              const SizedBox(height: 12),
              Text(
                '推定心拍の記録がある日だけ表示（${real.length}日分）。'
                '最小 ${real.reduce((a, b) => a < b ? a : b).round()}'
                ' 〜 最大 ${real.reduce((a, b) => a > b ? a : b).round()} bpm',
                style: AsakaoStyle.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 折れ線。[values] は日ごとの値で、記録のない日は null。
/// 隣り合う日がどちらも実値のときだけ線で結び、記録のない日は補間しない（点だけ描く）。
/// 「普段の範囲」の帯は心拍の基準値が無いので描かない。
class TrendLinePainter extends CustomPainter {
  TrendLinePainter(this.values);

  final List<double?> values;

  /// 実値のある日の数（点の数）。
  int get pointCount => values.where((v) => v != null).length;

  @override
  void paint(Canvas canvas, Size size) {
    final real = [for (final v in values) ?v];
    if (real.isEmpty) return;
    var lo = real.reduce((a, b) => a < b ? a : b);
    var hi = real.reduce((a, b) => a > b ? a : b);
    final pad = hi == lo ? 5.0 : (hi - lo) * 0.2;
    lo -= pad;
    hi += pad;
    final n = values.length;
    Offset? at(int i) {
      final v = values[i];
      if (v == null) return null;
      return Offset(
        (i + 0.5) / n * size.width,
        size.height - (v - lo) / (hi - lo) * size.height,
      );
    }

    final grid = Paint()
      ..color = AsakaoStyle.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      grid,
    );
    final line = Paint()
      ..color = AsakaoStyle.link
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = AsakaoStyle.link;
    for (var i = 0; i < n; i++) {
      final p = at(i);
      if (p == null) continue;
      final next = i + 1 < n ? at(i + 1) : null;
      if (next != null) canvas.drawLine(p, next, line);
      canvas.drawCircle(p, 4, dot);
    }
  }

  @override
  bool shouldRepaint(TrendLinePainter old) => old.values != values;
}
