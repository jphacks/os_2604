enum ScanMode {
  standard,
  research,
  legacyUnknown;

  String get label => switch (this) {
    standard => '通常モード',
    research => '研究モード',
    legacyUnknown => 'モード未記録（過去の記録）',
  };
}

enum MeasurementQuality { good, poor, interrupted }

enum HeartRateSource { none, rppgExperimental, external }

enum TemperatureSource { none, manual, healthPlatform }

enum ReportMode { onDevice, template }

/// Shared B/C record. Camera images are never part of this value.
class HealthCheckResult {
  HealthCheckResult({
    required this.id,
    required this.measuredAt,
    required this.elapsed,
    required this.faceDetected,
    required this.quality,
    this.scanMode = ScanMode.legacyUnknown,
    this.estimatedHeartRateBpm,
    this.heartRateSource = HeartRateSource.none,
    this.faceColorFeature,
    this.selfCondition,
    this.bodyTemperatureC,
    this.temperatureSource = TemperatureSource.none,
    this.reportText,
    this.aiMode,
  }) {
    if (id.trim().isEmpty || elapsed.isNegative) {
      throw ArgumentError(
        'A record needs an ID and non-negative elapsed time.',
      );
    }
    if (quality == MeasurementQuality.good &&
        (!faceDetected || elapsed < const Duration(seconds: 15))) {
      throw ArgumentError('A valid scan needs a face and at least 15 seconds.');
    }
    if (scanMode == ScanMode.standard &&
        (heartRateSource == HeartRateSource.rppgExperimental ||
            faceColorFeature != null)) {
      throw ArgumentError(
        'Standard scans cannot contain experimental signals.',
      );
    }
    final condition = selfCondition;
    if (condition != null && (condition < 1 || condition > 5)) {
      throw ArgumentError.value(selfCondition, 'selfCondition', 'must be 1..5');
    }
    _validateSource(
      estimatedHeartRateBpm,
      heartRateSource == HeartRateSource.none,
    );
    _validateSource(
      bodyTemperatureC,
      temperatureSource == TemperatureSource.none,
    );
    final colorFeature = faceColorFeature;
    if (colorFeature != null && !colorFeature.isFinite) {
      throw ArgumentError.value(faceColorFeature, 'faceColorFeature');
    }
    final text = reportText;
    if ((text == null) != (aiMode == null) ||
        (text != null && text.trim().isEmpty)) {
      throw ArgumentError(
        'Report text and its actual mode must be set together.',
      );
    }
  }

  final String id;

  /// Start of measurement, after preparation, in wall-clock time.
  final DateTime measuredAt;

  /// Actual observed duration, including any delay to the terminal frame.
  final Duration elapsed;
  static const targetDuration = Duration(seconds: 15);
  int get durationSec => targetDuration.inSeconds;
  final bool faceDetected;
  final MeasurementQuality quality;
  final ScanMode scanMode;
  final double? estimatedHeartRateBpm;
  final HeartRateSource heartRateSource;
  final double? faceColorFeature;
  final int? selfCondition;
  final double? bodyTemperatureC;
  final TemperatureSource temperatureSource;
  final String? reportText;

  /// Null until a report has actually been generated.
  final ReportMode? aiMode;

  static void _validateSource(double? value, bool hasNoSource) {
    if ((value == null) != hasNoSource ||
        (value != null && (!value.isFinite || value <= 0))) {
      throw ArgumentError(
        'A measured value needs a valid value and its source.',
      );
    }
  }
}
