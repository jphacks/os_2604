import 'package:test/test.dart';

import 'package:os_2604/models/health_check_result.dart';

void main() {
  HealthCheckResult record({
    Duration elapsed = const Duration(seconds: 15),
    bool faceDetected = true,
    int? condition,
    double? heartRate,
    HeartRateSource heartSource = HeartRateSource.none,
    double? temperature,
    TemperatureSource temperatureSource = TemperatureSource.none,
    String? report,
    ReportMode? mode,
  }) => HealthCheckResult(
    id: 'synthetic',
    measuredAt: DateTime.utc(2026, 10, 17),
    elapsed: elapsed,
    faceDetected: faceDetected,
    quality: MeasurementQuality.good,
    selfCondition: condition,
    estimatedHeartRateBpm: heartRate,
    heartRateSource: heartSource,
    bodyTemperatureC: temperature,
    temperatureSource: temperatureSource,
    reportText: report,
    aiMode: mode,
  );

  test('unmeasured values and an ungenerated report stay null', () {
    final value = record();
    expect(value.durationSec, 15);
    expect(value.estimatedHeartRateBpm, isNull);
    expect(value.bodyTemperatureC, isNull);
    expect(value.selfCondition, isNull);
    expect(value.reportText, isNull);
    expect(value.aiMode, isNull);
  });

  test('a good result cannot represent an incomplete or faceless scan', () {
    expect(
      () => record(elapsed: const Duration(milliseconds: 14999)),
      throwsArgumentError,
    );
    expect(() => record(faceDetected: false), throwsArgumentError);
  });

  test('self-reported condition is validated', () {
    expect(() => record(condition: 0), throwsArgumentError);
    expect(() => record(condition: 6), throwsArgumentError);
    expect(record(condition: 1).selfCondition, 1);
    expect(record(condition: 5).selfCondition, 5);
  });

  test('external values require matching source and valid numeric input', () {
    expect(() => record(heartRate: 72), throwsArgumentError);
    expect(
      () => record(heartSource: HeartRateSource.external),
      throwsArgumentError,
    );
    expect(() => record(temperature: 36.5), throwsArgumentError);
    expect(
      () => record(temperatureSource: TemperatureSource.manual),
      throwsArgumentError,
    );
    expect(
      () => record(
        temperature: double.nan,
        temperatureSource: TemperatureSource.manual,
      ),
      throwsArgumentError,
    );
    expect(
      record(
        temperature: 36.5,
        temperatureSource: TemperatureSource.manual,
      ).bodyTemperatureC,
      36.5,
    );
  });

  test('actual report mode is set together with text', () {
    expect(() => record(report: 'synthetic'), throwsArgumentError);
    expect(() => record(mode: ReportMode.template), throwsArgumentError);
    expect(
      () => record(report: ' ', mode: ReportMode.template),
      throwsArgumentError,
    );
    expect(
      record(report: '記録しました', mode: ReportMode.template).aiMode,
      ReportMode.template,
    );
  });
}
