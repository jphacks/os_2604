import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';

HealthCheckResult historyRec(
  String id,
  DateTime at, {
  int? cond,
  double? temp,
  double? hr,
  MeasurementQuality q = MeasurementQuality.good,
}) => HealthCheckResult(
  id: id,
  measuredAt: at,
  elapsed: const Duration(seconds: 15),
  faceDetected: true,
  quality: q,
  selfCondition: cond,
  bodyTemperatureC: temp,
  temperatureSource: temp == null
      ? TemperatureSource.none
      : TemperatureSource.manual,
  estimatedHeartRateBpm: hr,
  heartRateSource: hr == null
      ? HeartRateSource.none
      : HeartRateSource.rppgExperimental,
);

/// drift の watch() は購読解除後に Timer を残すため、テスト末尾で画面を外して流す。
void historyTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
