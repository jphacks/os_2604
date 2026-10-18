import 'package:flutter/material.dart';

import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// Inline year/month selector. Availability comes only from actual records.
class HistoryPeriodPicker extends StatelessWidget {
  const HistoryPeriodPicker({
    super.key,
    required this.year,
    required this.month,
    required this.expanded,
    required this.years,
    required this.availableMonths,
    required this.count,
    required this.onToggle,
    required this.onYear,
    required this.onMonth,
    required this.onWholeYear,
  });
  final int year;
  final int? month;
  final bool expanded;
  final List<int> years;
  final Set<int> availableMonths;
  final int count;
  final VoidCallback onToggle;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;
  final VoidCallback onWholeYear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            key: const ValueKey('history-period-toggle'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AsakaoStyle.ink,
              side: const BorderSide(color: AsakaoStyle.border),
              shape: const StadiumBorder(),
              minimumSize: const Size(48, 44),
            ),
            onPressed: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  month == null ? '$year年すべて' : '$year年$month月',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
          Text(
            '$count件',
            key: const ValueKey('history-period-count'),
            style: AsakaoStyle.caption,
          ),
        ],
      ),
      if (expanded) ...[
        const SizedBox(height: 10),
        AsakaoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('年', style: AsakaoStyle.caption),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final y in years)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          key: ValueKey('history-year-$y'),
                          style: TextButton.styleFrom(
                            backgroundColor: y == year
                                ? Colors.white
                                : AsakaoStyle.neutralBackground,
                            foregroundColor: AsakaoStyle.ink,
                            side: BorderSide(
                              color: y == year
                                  ? AsakaoStyle.border
                                  : Colors.transparent,
                            ),
                            minimumSize: const Size(120, 44),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => onYear(y),
                          child: Text('$y年'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('月', style: AsakaoStyle.caption),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 3 : 4;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 8) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var m = 1; m <= 12; m++)
                        SizedBox(
                          width: width,
                          child: TextButton(
                            key: ValueKey('history-month-$m'),
                            style: TextButton.styleFrom(
                              backgroundColor: month == m
                                  ? AsakaoStyle.coral
                                  : availableMonths.contains(m)
                                  ? Colors.white
                                  : AsakaoStyle.neutralBackground,
                              foregroundColor: AsakaoStyle.ink,
                              disabledBackgroundColor:
                                  AsakaoStyle.neutralBackground,
                              disabledForegroundColor: AsakaoStyle.muted
                                  .withValues(alpha: 0.5),
                              side: BorderSide(
                                color: availableMonths.contains(m) && month != m
                                    ? AsakaoStyle.border
                                    : Colors.transparent,
                              ),
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: availableMonths.contains(m)
                                ? () => onMonth(m)
                                : null,
                            child: Text('$m月'),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('history-whole-year'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsakaoStyle.ink,
                  side: const BorderSide(color: AsakaoStyle.border),
                  minimumSize: const Size(44, 48),
                ),
                onPressed: onWholeYear,
                child: Text('$year年をすべて表示'),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
