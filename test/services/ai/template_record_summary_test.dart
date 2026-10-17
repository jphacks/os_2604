import 'package:test/test.dart';

import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/services/ai/template_record_summary.dart';
import 'package:os_2604/services/analysis/history_baseline.dart';

void main() {
  const summary = TemplateRecordSummary();
  HealthCheckResult record({
    MeasurementQuality quality = MeasurementQuality.good,
    int? condition,
    double? rate,
    HeartRateSource heartSource = HeartRateSource.none,
    double? faceColorFeature,
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
    faceColorFeature: faceColorFeature,
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

  test('renders accumulating baseline without inventing a median', () {
    final fewValid = summary.format(
      record(condition: 4),
      baseline: const HistoryBaseline(
        validRecordCount: 2,
        selfConditionCount: 2,
        selfConditionMedian: null,
      ),
    );
    expect(fewValid, contains('過去比較：基準値蓄積中（有効記録 2/3件）'));
    expect(fewValid, isNot(contains('中央値')));

    final fewCondition = summary.format(
      record(condition: 4),
      baseline: const HistoryBaseline(
        validRecordCount: 4,
        selfConditionCount: 2,
        selfConditionMedian: null,
      ),
    );
    expect(fewCondition, contains('過去比較：基準値蓄積中（体調の記録 2/3件）'));
    expect(fewCondition, isNot(contains('中央値')));
  });

  test('renders past 7-day median comparison when baseline is available', () {
    const baseline = HistoryBaseline(
      validRecordCount: 4,
      selfConditionCount: 3,
      selfConditionMedian: 3.5,
    );
    final higher = summary.format(record(condition: 4), baseline: baseline);
    expect(
      higher,
      contains('過去比較：直近7日間（今日を除く）の体調の中央値 3.5 / 5（今回 4 / 5、中央値より +0.5、有効記録 4件）'),
    );

    final lower = summary.format(record(condition: 2), baseline: baseline);
    expect(
      lower,
      contains('過去比較：直近7日間（今日を除く）の体調の中央値 3.5 / 5（今回 2 / 5、中央値より -1.5、有効記録 4件）'),
    );

    final same = summary.format(
      record(condition: 3),
      baseline: const HistoryBaseline(
        validRecordCount: 3,
        selfConditionCount: 3,
        selfConditionMedian: 3,
      ),
    );
    expect(
      same,
      contains('過去比較：直近7日間（今日を除く）の体調の中央値 3 / 5（今回 3 / 5、中央値と同じ、有効記録 3件）'),
    );

    final unentered = summary.format(record(), baseline: baseline);
    expect(
      unentered,
      contains('過去比較：直近7日間（今日を除く）の体調の中央値 3.5 / 5（有効記録 4件、今回の体調：未入力）'),
    );
  });

  test('experimental face color formatting is explicit and separated from normal report', () {
    expect(summary.formatExperimentalFaceColor(record()), '顔色特徴量：未測定');
    final withColor = record(faceColorFeature: 0.4512);
    expect(summary.format(withColor), isNot(contains('0.4512')));
    final colorText = summary.formatExperimentalFaceColor(withColor);
    expect(colorText, contains('0.4512'));
    expect(colorText, contains('実験値'));
    expect(colorText, contains('診断値ではありません'));

    final poorColor = record(
      quality: MeasurementQuality.poor,
      faceColorFeature: 0.4512,
    );
    expect(
      summary.formatExperimentalFaceColor(poorColor),
      contains('顔色特徴量：非表示'),
    );
  });
}
