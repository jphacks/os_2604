import 'package:test/test.dart';

import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/ai/template_record_summary.dart';

void main() {
  const summary = TemplateRecordSummary();
  HealthCheckResult record({
    MeasurementQuality quality = MeasurementQuality.good,
    int? condition,
    double? rate,
    HeartRateSource heartSource = HeartRateSource.none,
    double? temperature,
    TemperatureSource temperatureSource = TemperatureSource.none,
  }) => HealthCheckResult(
    id: 'synthetic-record',
    measuredAt: DateTime.utc(2026, 10, 17),
    elapsed: quality == MeasurementQuality.good
        ? const Duration(seconds: 15)
        : const Duration(seconds: 3),
    faceDetected: quality == MeasurementQuality.good,
    quality: quality,
    selfCondition: condition,
    estimatedHeartRateBpm: rate,
    heartRateSource: heartSource,
    bodyTemperatureC: temperature,
    temperatureSource: temperatureSource,
  );

  test('unmeasured values remain unmeasured without dummy normal values', () {
    final text = summary.format(record());
    expect(text, contains('体調（自己申告）：未入力'));
    expect(text, contains('心拍数：未測定'));
    expect(text, contains('体温：未測定'));
    expect(text, contains('体温はカメラで測定していません'));
    expect(RegExp(r'\d').hasMatch(text), isFalse);
  });

  test('template mode is explicit and the input record remains unmodified', () {
    final scan = record();
    expect(summary.mode, ReportMode.template);
    expect(summary.format(scan), contains('生成モード：定型文'));
    expect(scan.reportText, isNull);
    expect(scan.aiMode, isNull);
    expect(scan.bodyTemperatureC, isNull);
  });

  test(
    'self-reported condition is displayed without health interpretation',
    () {
      for (var value = 1; value <= 5; value++) {
        final text = summary.format(record(condition: value));
        expect(text, contains('体調（自己申告）：$value / 5'));
        expect(text, isNot(contains('健康状態は良好')));
      }
    },
  );

  test(
    'manual temperature shows its source and preserves stored precision',
    () {
      final text = summary.format(
        record(temperature: 36.45, temperatureSource: TemperatureSource.manual),
      );
      expect(text, contains('体温：36.45 °C（手入力・外部体温計）'));
      expect(text, contains('体温はカメラで測定していません'));
    },
  );

  test('platform temperature is distinguished from manual input', () {
    final text = summary.format(
      record(
        temperature: 36.5,
        temperatureSource: TemperatureSource.healthPlatform,
      ),
    );
    expect(text, contains('健康プラットフォーム由来の記録'));
    expect(text, isNot(contains('手入力')));
  });

  test('rPPG rate is explicitly experimental without rounding the value', () {
    final text = summary.format(
      record(rate: 72.35, heartSource: HeartRateSource.rppgExperimental),
    );
    expect(text, contains('72.35 bpm'));
    expect(text, contains('rPPGによる試験的推定'));
    expect(text, contains('医療的な実測値ではありません'));
  });

  test('external heart rate is not mislabeled as a camera estimate', () {
    final text = summary.format(
      record(rate: 72, heartSource: HeartRateSource.external),
    );
    expect(text, contains('心拍数：72 bpm（外部由来の記録）'));
    expect(text, isNot(contains('rPPG')));
  });

  for (final quality in [
    MeasurementQuality.poor,
    MeasurementQuality.interrupted,
  ]) {
    test('$quality hides a stored heart rate and suggests retry', () {
      final text = summary.format(
        record(
          quality: quality,
          rate: 72.35,
          heartSource: HeartRateSource.rppgExperimental,
        ),
      );
      expect(text, contains('心拍数：非表示'));
      expect(text, isNot(contains('72.35')));
      expect(text, isNot(contains('bpm')));
      expect(text, contains('再測定してください'));
      expect(text, isNot(contains('撮影品質：確認済み')));
    });
  }

  test('does not invent history availability, comparison or persistence', () {
    final text = summary.format(record());
    expect(text, isNot(contains('基準値蓄積中')));
    expect(text, isNot(contains('中央値')));
    expect(text, isNot(contains('保存しました')));
    expect(text, contains('診断目的ではありません'));
  });
}
