import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/analysis/history_baseline.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// A deterministic reflection of recorded facts, independent of AI availability.
class TodayInsightCard extends StatelessWidget {
  const TodayInsightCard({
    super.key,
    required this.record,
    required this.baseline,
    this.title = '今日の気づき',
  });

  final HealthCheckResult record;
  final HistoryBaseline? baseline;
  final String title;

  String _number(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  @override
  Widget build(BuildContext context) {
    final condition = record.selfCondition;
    final b = baseline;
    final median = b?.selfConditionMedian;
    final good = record.quality == MeasurementQuality.good;
    final diff = good && condition != null && median != null
        ? condition - median
        : null;
    final heading = !good
        ? '今回は比較を表示できません'
        : b == null
        ? '過去の記録を読み込めませんでした'
        : b.isAccumulating
        ? '基準値を蓄積中'
        : condition == null
        ? '体調を入力すると普段と比べられます'
        : diff == 0
        ? '自己申告は普段と同じです'
        : diff! > 0
        ? '自己申告は普段より高めです'
        : '自己申告は普段より低めです';
    final message = !good
        ? '撮影品質が不足しているため、この記録では比較しません。'
        : b == null
        ? '比較値は表示していません。時間をおいて記録を開き直してください。'
        : b.isAccumulating
        ? 'あと${3 - b.selfConditionCount.clamp(0, 3)}件、体調つきで記録すると普段との比較を表示します。'
        : condition == null
        ? '今回は体調が未入力です。過去の中央値だけを表示しています。'
        : diff == 0
        ? '同じ自己申告の日は、どんな朝でしたか。過去の記録も振り返ってみましょう。'
        : '思い当たることはありますか。過去の記録と見比べてみましょう。';

    return AsakaoCard(
      key: const ValueKey('today-insight-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AsakaoStyle.coralInk,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AsakaoStyle.heading)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            heading,
            key: const ValueKey('insight-heading'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AsakaoStyle.ink,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, label, value) in [
                    (
                      'current',
                      '今回の体調',
                      condition == null ? '未入力' : '$condition / 5',
                    ),
                    (
                      'median',
                      '7日の中央値',
                      !good || median == null ? '—' : '${_number(median)} / 5',
                    ),
                    (
                      'difference',
                      '中央値との差',
                      diff == null
                          ? '比較なし'
                          : '${diff > 0 ? '+' : ''}${_number(diff)}',
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AsakaoStyle.coralPale,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: AsakaoStyle.caption),
                              const SizedBox(height: 4),
                              Text(
                                value,
                                key: ValueKey('insight-$key'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AsakaoStyle.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(message, style: AsakaoStyle.body),
          if (good && b != null) ...[
            const SizedBox(height: 10),
            if (b.isAccumulating)
              Text(
                '${b.selfConditionCount.clamp(0, 3)} / 3',
                style: AsakaoStyle.caption,
              ),
            Text(
              '記録日を除く直近7日・体調入力 ${b.selfConditionCount}件。'
              '自己申告の比較であり、健康状態の判定ではありません。',
              style: AsakaoStyle.caption,
            ),
          ],
        ],
      ),
    );
  }
}
