import '../../models/health_check_result.dart';

/// Deterministic current-record text for a future template-report service.
///
/// This component does not save records, compare history or invoke an AI model.
/// The report API will attach generation time and mode after B/C integration.
class TemplateRecordSummary {
  const TemplateRecordSummary();

  ReportMode get mode => ReportMode.template;

  String format(HealthCheckResult scan) => '生成モード：定型文\n${formatRecord(scan)}';

  /// Record facts without a generation label, for composing the actual mode.
  String formatRecord(HealthCheckResult scan) {
    final condition = scan.selfCondition;
    final temperature = scan.bodyTemperatureC;
    return [
      switch (scan.quality) {
        MeasurementQuality.good => '撮影品質：確認済み',
        MeasurementQuality.poor => '撮影品質：不足しています。再測定してください。',
        MeasurementQuality.interrupted => '撮影は中断されました。再測定してください。',
      },
      '体調（自己申告）：${condition == null ? '未入力' : '$condition / 5'}',
      _heartRate(scan),
      temperature == null
          ? '体温：未測定'
          : '体温：${_number(temperature)} °C（${_temperatureSource(scan.temperatureSource)}）',
      '体温はカメラで測定していません。',
      'この記録は診断目的ではありません。',
    ].join('\n');
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

  // Preserve recorded precision; do not round, estimate or fill missing values.
  String _number(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
