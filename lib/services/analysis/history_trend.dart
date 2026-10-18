import '../../models/health_check_result.dart';

/// 推移グラフの1日分。値は実際の記録だけから求め、無い日は null のまま。
class DailyTrend {
  const DailyTrend({required this.day, this.condition, this.heartRateBpm});

  /// 端末のローカル日付（時刻は 0:00）。
  final DateTime day;

  /// その日の体調（1〜5）。記録がない・未入力なら null。
  final int? condition;

  /// その日の推定心拍。品質良好の記録に実際の値がある日だけ。
  final double? heartRateBpm;
}

/// [today] を最後の日とする直近 [days] 日（今日を含む）の日別推移。古い日から順。
///
/// 同じ日に複数の記録があるときは、その日の「最新の記録」を使う。
/// - 体調：体調が入力されている記録のうち最新のもの（自己申告なので測定品質は問わない）。
/// - 推定心拍：品質良好で心拍値がある記録のうち最新のもの。
/// 日付は端末のローカル日付で判定する。
List<DailyTrend> buildDailyTrend(
  Iterable<HealthCheckResult> records, {
  required DateTime today,
  required int days,
}) {
  final t = today.toLocal();
  final last = DateTime(t.year, t.month, t.day);
  // 新しい順に並べておき、日ごとに最初に見つかった値を採用する。
  final newestFirst = [...records]
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return [
    for (var i = days - 1; i >= 0; i--)
      _dayOf(newestFirst, DateTime(last.year, last.month, last.day - i)),
  ];
}

DailyTrend _dayOf(List<HealthCheckResult> newestFirst, DateTime day) {
  int? condition;
  double? heartRate;
  for (final r in newestFirst) {
    final at = r.measuredAt.toLocal();
    if (at.year != day.year || at.month != day.month || at.day != day.day) {
      continue;
    }
    condition ??= r.selfCondition;
    if (r.quality == MeasurementQuality.good) {
      heartRate ??= r.estimatedHeartRateBpm;
    }
  }
  return DailyTrend(day: day, condition: condition, heartRateBpm: heartRate);
}

/// 体調の平均。値がある日が 1 日もなければ null。
double? averageCondition(Iterable<DailyTrend> days) {
  final values = [
    for (final d in days)
      if (d.condition != null) d.condition!,
  ];
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
