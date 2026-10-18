import '../../models/health_check_result.dart';
import '../analysis/history_baseline.dart';

/// Deterministic current-record text for a future template-report service.
///
/// This component does not save records, compare history or invoke an AI model.
/// The report API will attach generation time and mode after B/C integration.
class TemplateRecordSummary {
  const TemplateRecordSummary();

  ReportMode get mode => ReportMode.template;

  String format(HealthCheckResult scan, {HistoryBaseline? baseline}) =>
      '生成モード：定型文\n${formatRecord(scan, baseline: baseline)}';

  /// Record facts without a generation label, for composing the actual mode.
  String formatRecord(HealthCheckResult scan, {HistoryBaseline? baseline}) {
    final condition = scan.selfCondition;
    final temperature = scan.bodyTemperatureC;
    return [
      '計測モード：${scan.scanMode.label}',
      if (scan.scanMode == ScanMode.research)
        '研究用の試験機能です。心拍・顔色を健康状態の判定に使用しないでください。',
      switch (scan.quality) {
        MeasurementQuality.good => '撮影品質：確認済み',
        MeasurementQuality.poor => '撮影品質：不足しています。再測定してください。',
        MeasurementQuality.interrupted => '撮影は中断されました。再測定してください。',
      },
      '体調（自己申告）：${condition == null ? '未入力' : '$condition / 5'}',
      if (baseline != null) _baselineComparison(scan, baseline),
      _heartRate(scan),
      temperature == null
          ? '体温：未測定'
          : '体温：${_number(temperature)} °C（${_temperatureSource(scan.temperatureSource)}）',
      '体温はカメラで測定していません。',
      'この記録は診断目的ではありません。',
    ].join('\n');
  }

  String _baselineComparison(HealthCheckResult scan, HistoryBaseline baseline) {
    final median = baseline.selfConditionMedian;
    if (median == null) {
      return baseline.validRecordCount < 3
          ? '過去比較：基準値蓄積中（有効記録 ${baseline.validRecordCount}/3件）'
          : '過去比較：基準値蓄積中（体調の記録 ${baseline.selfConditionCount}/3件）';
    }
    final medianText = _number(median);
    final current = scan.selfCondition;
    if (current == null) {
      return '過去比較：直近7日間（今日を除く）の体調の中央値 $medianText / 5'
          '（有効記録 ${baseline.validRecordCount}件、今回の体調：未入力）';
    }
    final diff = current - median;
    final diffText = diff == 0
        ? '中央値と同じ'
        : diff > 0
        ? '中央値より +${_number(diff)}'
        : '中央値より ${_number(diff)}';
    return '過去比較：直近7日間（今日を除く）の体調の中央値 $medianText / 5'
        '（今回 $current / 5、$diffText、有効記録 ${baseline.validRecordCount}件）';
  }

  String _heartRate(HealthCheckResult scan) {
    // Do not expose even a stored numeric value when scan quality is insufficient.
    if (scan.quality != MeasurementQuality.good) {
      return '心拍数：非表示（撮影品質が不足、または撮影が中断されました）';
    }
    final rate = scan.estimatedHeartRateBpm;
    if (rate == null) return '心拍数：未測定';
    final source = switch (scan.heartRateSource) {
      HeartRateSource.rppgExperimental => 'rPPGによる試験的推定。医療的な実測値ではありません',
      HeartRateSource.external => '外部由来の記録',
      HeartRateSource.none =>
        '出典なし', // Rejected by the shared model constructor.
    };
    return '心拍数：${_number(rate)} bpm（$source）';
  }

  String _temperatureSource(TemperatureSource source) => switch (source) {
    TemperatureSource.manual => '手入力・外部体温計',
    TemperatureSource.healthPlatform => '健康プラットフォーム由来の記録',
    TemperatureSource.none => '出典なし', // Rejected for non-null temperatures.
  };

  /// Formats P2 experimental facial color feature for verification mode only.
  /// Never included in standard health judgment or P0/P1 [formatRecord] text.
  String formatExperimentalFaceColor(HealthCheckResult scan) {
    if (scan.quality != MeasurementQuality.good) {
      return '顔色特徴量：非表示（撮影品質が不足、または撮影が中断されました）';
    }
    final feature = scan.faceColorFeature;
    if (feature == null) return '顔色特徴量：未測定';
    return '顔色特徴量：${_number(feature)}（正規化赤み比・実験値。診断値ではありません）';
  }

  // Preserve recorded precision; do not round, estimate or fill missing values.
  String _number(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
