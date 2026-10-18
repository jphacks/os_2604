import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../widgets/self_condition_input.dart';
import 'asakao_style.dart';
import 'asakao_widgets.dart';

/// 結果画面と履歴詳細で共有する、1件の記録の表示部品。
/// 値は記録にある実データだけを出し、null は「未入力」、心拍は品質良好のときだけ表示する。

const asakaoWeekdays = ['月', '火', '水', '木', '金', '土', '日'];

/// 「10月16日（金）」
String formatJaDate(DateTime d) {
  final l = d.toLocal();
  return '${l.month}月${l.day}日（${asakaoWeekdays[l.weekday - 1]}）';
}

/// 「7:08」
String formatClock(DateTime d) {
  final l = d.toLocal();
  return '${l.hour}:${l.minute.toString().padLeft(2, '0')}';
}

/// 体調の比較キャプション。差が 0 なら「普段どおり」。
String recordComparisonCaption(double diff) {
  if (diff == 0) return '普段どおり';
  final n = diff.abs() == diff.abs().roundToDouble()
      ? diff.abs().round().toString()
      : diff.abs().toString();
  return '普段より ${diff > 0 ? '+' : '-'}$n';
}

String _temperatureSourceLabel(TemperatureSource s) => switch (s) {
  TemperatureSource.manual => '手入力',
  TemperatureSource.healthPlatform => 'ヘルスプラットフォーム',
  TemperatureSource.none => '出典なし',
};

/// 計測品質カード（棒アイコン + 品質チップ + 顔検出・計測時間）。
class RecordQualityCard extends StatelessWidget {
  const RecordQualityCard(this.record, {super.key, this.fullBleed = false});

  final HealthCheckResult record;

  /// 画面の左右いっぱいに広げ、角丸にしない。
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final level = switch (r.quality) {
      MeasurementQuality.good => 4,
      MeasurementQuality.poor => 1,
      MeasurementQuality.interrupted => 0,
    };
    final color = switch (r.quality) {
      MeasurementQuality.good => AsakaoStyle.goodInk,
      MeasurementQuality.poor => AsakaoStyle.poorInk,
      MeasurementQuality.interrupted => AsakaoStyle.muted,
    };
    return AsakaoCard(
      fullBleed: fullBleed,
      padding: fullBleed
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
          : const EdgeInsets.all(16),
      child: Row(
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: 28,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 6,
                      height: 8.0 + i * 6,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: i < level ? color : AsakaoStyle.disabled,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '計測品質',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AsakaoStyle.ink,
                      ),
                    ),
                    AsakaoQualityChip(r.quality),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '顔検出：${r.faceDetected ? 'あり' : 'なし'}　計測時間 '
                  '${(r.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
                  style: AsakaoStyle.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 体調・体温・推定心拍（参考値）・顔色特徴量の行カード。
/// [conditionDiff] は実際の基準値との差。null なら比較は出さない。
class RecordValuesCard extends StatelessWidget {
  const RecordValuesCard(
    this.record, {
    super.key,
    this.conditionDiff,
    this.fullBleed = false,
    this.extra,
  });

  final HealthCheckResult record;
  final double? conditionDiff;

  /// 末尾に足す行（区切り線も含めて渡す）。例: 結果画面の室温・湿度。
  final Widget? extra;

  /// 画面の左右いっぱいに広げ、角丸にしない。
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final cond = r.selfCondition;
    final diff = conditionDiff;
    final t = r.bodyTemperatureC;
    final hr = r.estimatedHeartRateBpm;
    final showHr = hr != null && r.quality == MeasurementQuality.good;
    final feature = r.faceColorFeature;
    // 全幅のときは区切り線をフレームまで引き、文字の行だけを内側に寄せる。
    Widget row(Widget child) => fullBleed
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          )
        : child;
    return AsakaoCard(
      fullBleed: fullBleed,
      padding: fullBleed
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          row(
            RecordRow(
              title: '体調',
              subtitle: '自分で入力',
              value: cond == null
                  ? '未入力'
                  : '$cond / 5 ${selfConditionLabel(cond)}',
              caption: cond == null || diff == null
                  ? null
                  : recordComparisonCaption(diff),
            ),
          ),
          const Divider(),
          row(
            RecordRow(
              title: '体温',
              subtitle: t == null
                  ? '体温計'
                  : '体温計（${_temperatureSourceLabel(r.temperatureSource)}）',
              value: t == null ? '未入力' : '$t℃',
            ),
          ),
          if (showHr) ...[
            const Divider(),
            row(
              RecordRow(
                title: '推定心拍',
                badge: '参考値',
                subtitle: r.heartRateSource == HeartRateSource.external
                    ? '外部の記録'
                    : 'カメラから推定（研究モード）',
                value: '${hr.round()} bpm',
              ),
            ),
          ],
          if (feature != null) ...[
            const Divider(),
            row(
              RecordRow(title: '顔色特徴量', subtitle: '研究モード', value: '$feature'),
            ),
          ],
          ?extra,
        ],
      ),
    );
  }
}

/// レポートカード。作成済みなら実際の生成モードと本文、未作成なら [missingText]。
class RecordReportCard extends StatelessWidget {
  const RecordReportCard(
    this.record, {
    super.key,
    required this.missingText,
    this.fallbackNote,
    this.fullBleed = false,
  });

  final HealthCheckResult record;
  final String missingText;

  /// 画面の左右いっぱいに広げ、角丸にしない。
  final bool fullBleed;

  /// 定型文に切り替わった理由（結果画面で生成直後だけ分かる）。
  final String? fallbackNote;

  @override
  Widget build(BuildContext context) {
    final text = record.reportText;
    return AsakaoCard(
      fullBleed: fullBleed,
      padding: fullBleed
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null) ...[
            Text(
              record.aiMode == ReportMode.onDevice ? '端末内AIで作成' : '定型文',
              style: AsakaoStyle.caption,
            ),
            if (record.aiMode == ReportMode.template && fallbackNote != null)
              Text(fallbackNote!, style: AsakaoStyle.caption),
            const SizedBox(height: 8),
          ],
          Text(text ?? missingText, style: AsakaoStyle.body),
        ],
      ),
    );
  }
}

class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.badge,
    this.caption,
  });

  final String title;
  final String subtitle;
  final String value;
  final String? badge;
  final String? caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AsakaoStyle.ink,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AsakaoStyle.neutralBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AsakaoStyle.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AsakaoStyle.caption),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AsakaoStyle.ink,
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AsakaoStyle.link,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
