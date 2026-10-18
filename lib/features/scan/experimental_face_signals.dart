import 'dart:math';
import 'dart:typed_data';

import 'frame_luminance.dart';

/// Pulse extraction methods for P2 experimental 15-second rPPG verification.
enum RppgAlgorithm { pos, chrom }

/// In-memory per-frame facial skin RGB average. Raw frame bytes are never kept.
class FaceRgbSample {
  const FaceRgbSample({
    required this.red,
    required this.green,
    required this.blue,
  });

  final double red;
  final double green;
  final double blue;

  bool get isValid =>
      red.isFinite &&
      green.isFinite &&
      blue.isFinite &&
      red >= 0 &&
      red <= 255 &&
      green >= 0 &&
      green <= 255 &&
      blue >= 0 &&
      blue <= 255;

  /// Weighted RGB brightness matching [meanFrameLuminance] for BGRA8888.
  double get luminance => 0.2126 * red + 0.7152 * green + 0.0722 * blue;

  /// Illumination-normalized redness chromaticity R / (R + G + B) in (0, 1).
  ///
  /// This is an appearance feature for P2 relative comparison, not a diagnosis.
  double? get normalizedRedness {
    if (!isValid) return null;
    final total = red + green + blue;
    if (!total.isFinite || total <= 0) return null;
    final ratio = red / total;
    return ratio.isFinite && ratio > 0 && ratio < 1 ? ratio : null;
  }
}

/// Timestamped facial skin sample captured during the 15-second measurement.
class TimedFaceRgbSample {
  const TimedFaceRgbSample({required this.capturedAt, required this.sample});

  final Duration capturedAt;
  final FaceRgbSample sample;
}

/// Configuration for P2 experimental facial color and 15-second rPPG analysis.
class ExperimentalFaceSignalConfig {
  ExperimentalFaceSignalConfig({
    this.rppgAlgorithm = RppgAlgorithm.pos,
    this.minColorSamples = 30,
    this.minRppgSamples = 120,
    this.minWindowDuration = const Duration(seconds: 14),
    this.maxSampleGap = const Duration(milliseconds: 500),
    this.faceDetectionInterval = const Duration(milliseconds: 180),
    this.faceDetectionDownsampleFactor = 4,
    this.minLuminance = 50,
    this.maxLuminance = 245,
    this.maxLuminanceVariationCoeff = 0.15,
    this.minHeartRateBpm = 48,
    this.maxHeartRateBpm = 180,
    this.minPeakPowerRatio = 0.24,
    this.minProminenceRatio = 1.4,
  }) {
    if (minColorSamples <= 0 ||
        minRppgSamples < 30 ||
        minWindowDuration <= Duration.zero ||
        maxSampleGap <= Duration.zero ||
        faceDetectionInterval < Duration.zero ||
        faceDetectionInterval >= maxSampleGap ||
        faceDetectionDownsampleFactor < 1 ||
        faceDetectionDownsampleFactor > 8 ||
        !minLuminance.isFinite ||
        !maxLuminance.isFinite ||
        minLuminance <= 0 ||
        minLuminance >= maxLuminance ||
        maxLuminance > 255 ||
        !maxLuminanceVariationCoeff.isFinite ||
        maxLuminanceVariationCoeff <= 0 ||
        maxLuminanceVariationCoeff > 1 ||
        !minHeartRateBpm.isFinite ||
        !maxHeartRateBpm.isFinite ||
        minHeartRateBpm < 30 ||
        minHeartRateBpm >= maxHeartRateBpm ||
        maxHeartRateBpm > 220 ||
        !minPeakPowerRatio.isFinite ||
        minPeakPowerRatio <= 0 ||
        minPeakPowerRatio >= 1 ||
        !minProminenceRatio.isFinite ||
        minProminenceRatio <= 1) {
      throw ArgumentError('Invalid experimental face signal configuration.');
    }
  }

  final RppgAlgorithm rppgAlgorithm;
  final int minColorSamples;
  final int minRppgSamples;
  final Duration minWindowDuration;
  final Duration maxSampleGap;

  /// Minimum interval between full ML Kit face detections during high-rate
  /// 30fps RGB sampling. Must remain below [maxSampleGap].
  final Duration faceDetectionInterval;

  /// Spatial downsample factor applied only to the transient buffer passed to
  /// ML Kit face detection on high-resolution frames (>= 640x360) so main-thread
  /// image conversion does not stall 30fps RGB streaming.
  final int faceDetectionDownsampleFactor;

  final double minLuminance;
  final double maxLuminance;
  final double maxLuminanceVariationCoeff;
  final double minHeartRateBpm;
  final double maxHeartRateBpm;
  final double minPeakPowerRatio;
  final double minProminenceRatio;
}

/// Summary of ambient shooting conditions recorded alongside P2 color features.
class ShootingConditionSummary {
  const ShootingConditionSummary({
    required this.sampleCount,
    required this.meanLuminance,
    required this.minLuminance,
    required this.maxLuminance,
    required this.luminanceVariationCoeff,
    required this.isLightingStable,
    this.effectiveFps = 0,
  });

  final int sampleCount;
  final double meanLuminance;
  final double minLuminance;
  final double maxLuminance;
  final double luminanceVariationCoeff;
  final bool isLightingStable;
  final double effectiveFps;
}

/// Result of P2 experimental evaluation at the end of a 15-second scan.
///
/// Unreliable or low-quality signals stay null so P0/P1 records never receive
/// dummy numbers or unverified heart rate values.
class ExperimentalFaceSignalEvaluation {
  const ExperimentalFaceSignalEvaluation({
    this.faceColorFeature,
    this.shootingConditions,
    this.estimatedHeartRateBpm,
    this.peakPowerRatio,
    this.prominenceRatio,
    this.rppgAlgorithm,
  });

  final double? faceColorFeature;
  final ShootingConditionSummary? shootingConditions;
  final double? estimatedHeartRateBpm;
  final double? peakPowerRatio;
  final double? prominenceRatio;
  final RppgAlgorithm? rppgAlgorithm;
}

/// Transient downsampled BGRA8888 buffer for fast ML Kit face detection.
class DownsampledBgraFrame {
  const DownsampledBgraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.scaleX,
    required this.scaleY,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final double scaleX;
  final double scaleY;
}

/// Downsamples a high-resolution BGRA8888 frame for ML Kit face detection while
/// keeping small synthetic test frames untouched.
DownsampledBgraFrame downsampleBgra8888ForDetection({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  required int factor,
}) {
  if (factor <= 1 || width < 640 || height < 360) {
    return DownsampledBgraFrame(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
      scaleX: 1.0,
      scaleY: 1.0,
    );
  }
  final dstWidth = width ~/ factor;
  final dstHeight = height ~/ factor;
  if (dstWidth <= 0 || dstHeight <= 0) {
    return DownsampledBgraFrame(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
      scaleX: 1.0,
      scaleY: 1.0,
    );
  }
  final dstBytesPerRow = dstWidth * 4;
  final dst = Uint8List(dstBytesPerRow * dstHeight);
  var dstOffset = 0;
  for (var y = 0; y < dstHeight; y++) {
    final srcRowStart = (y * factor) * bytesPerRow;
    for (var x = 0; x < dstWidth; x++) {
      final srcOffset = srcRowStart + (x * factor) * 4;
      dst[dstOffset] = bytes[srcOffset];
      dst[dstOffset + 1] = bytes[srcOffset + 1];
      dst[dstOffset + 2] = bytes[srcOffset + 2];
      dst[dstOffset + 3] = bytes[srcOffset + 3];
      dstOffset += 4;
    }
  }
  return DownsampledBgraFrame(
    bytes: dst,
    width: dstWidth,
    height: dstHeight,
    bytesPerRow: dstBytesPerRow,
    scaleX: width / dstWidth,
    scaleY: height / dstHeight,
  );
}

/// Stabilizes [candidate] against small detector bounding-box quantization
/// jitter so 30fps RGB sampling uses a consistent pixel region while stationary.
FrameRegion stabilizeFaceRegion(
  FrameRegion candidate, {
  FrameRegion? previous,
  double deadbandFraction = 0.03,
}) {
  if (previous == null || previous.width <= 0 || previous.height <= 0) {
    return candidate;
  }
  final prevCenterX = previous.left + previous.width / 2.0;
  final prevCenterY = previous.top + previous.height / 2.0;
  final candCenterX = candidate.left + candidate.width / 2.0;
  final candCenterY = candidate.top + candidate.height / 2.0;

  final dx = (candCenterX - prevCenterX).abs() / previous.width;
  final dy = (candCenterY - prevCenterY).abs() / previous.height;
  final dw = (candidate.width - previous.width).abs() / previous.width;
  final dh = (candidate.height - previous.height).abs() / previous.height;

  if (dx <= deadbandFraction &&
      dy <= deadbandFraction &&
      dw <= deadbandFraction &&
      dh <= deadbandFraction) {
    return previous;
  }
  return candidate;
}

/// Extracts an inner facial skin sub-region (forehead/cheeks) from [faceRegion]
/// to reduce background, hair and boundary artifacts during RGB sampling.
FrameRegion? extractSkinRoiRegion(FrameRegion faceRegion) {
  if (faceRegion.left < 0 ||
      faceRegion.top < 0 ||
      faceRegion.width <= 0 ||
      faceRegion.height <= 0) {
    return null;
  }
  final leftOffset = (faceRegion.width * 0.25).floor();
  final rightOffset = (faceRegion.width * 0.75).ceil();
  final topOffset = (faceRegion.height * 0.25).floor();
  final bottomOffset = (faceRegion.height * 0.75).ceil();

  final left = faceRegion.left + leftOffset;
  final top = faceRegion.top + topOffset;
  final maxWidth = faceRegion.width - leftOffset;
  final maxHeight = faceRegion.height - topOffset;
  if (maxWidth <= 0 || maxHeight <= 0) return null;

  final width = (rightOffset - leftOffset).clamp(1, maxWidth);
  final height = (bottomOffset - topOffset).clamp(1, maxHeight);
  return FrameRegion(left: left, top: top, width: width, height: height);
}

/// Computes mean facial skin RGB in 0..255 from a BGRA8888 buffer.
///
/// Returns null if buffer metadata or [faceRegion] is invalid. Does not retain
/// or persist [bytes].
FaceRgbSample? sampleFaceRgbBgra8888({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  required FrameRegion faceRegion,
  bool useInnerSkinRoi = true,
}) {
  const bytesPerPixel = 4;
  if (width <= 0 ||
      height <= 0 ||
      bytesPerRow <= 0 ||
      width > bytes.length ~/ bytesPerPixel) {
    return null;
  }
  final pixelRowBytes = width * bytesPerPixel;
  if (bytesPerRow < pixelRowBytes ||
      height - 1 > (bytes.length - pixelRowBytes) ~/ bytesPerRow) {
    return null;
  }
  if (faceRegion.left < 0 ||
      faceRegion.top < 0 ||
      faceRegion.width <= 0 ||
      faceRegion.height <= 0 ||
      faceRegion.left > width ||
      faceRegion.top > height ||
      faceRegion.width > width - faceRegion.left ||
      faceRegion.height > height - faceRegion.top) {
    return null;
  }

  final roi = useInnerSkinRoi ? extractSkinRoiRegion(faceRegion) : faceRegion;
  if (roi == null ||
      roi.left < 0 ||
      roi.top < 0 ||
      roi.width <= 0 ||
      roi.height <= 0 ||
      roi.left > width ||
      roi.top > height ||
      roi.width > width - roi.left ||
      roi.height > height - roi.top) {
    return null;
  }

  var sumB = 0.0;
  var sumG = 0.0;
  var sumR = 0.0;
  for (var y = roi.top; y < roi.top + roi.height; y++) {
    for (var x = roi.left; x < roi.left + roi.width; x++) {
      final offset = y * bytesPerRow + x * bytesPerPixel;
      sumB += bytes[offset];
      sumG += bytes[offset + 1];
      sumR += bytes[offset + 2];
    }
  }
  final count = roi.width * roi.height;
  return FaceRgbSample(
    red: (sumR / count).clamp(0.0, 255.0),
    green: (sumG / count).clamp(0.0, 255.0),
    blue: (sumB / count).clamp(0.0, 255.0),
  );
}

/// Evaluates P2 facial color feature and 15-second rPPG heart rate from
/// measurement-phase samples.
ExperimentalFaceSignalEvaluation evaluateExperimentalFaceSignals(
  List<TimedFaceRgbSample> samples,
  ExperimentalFaceSignalConfig config,
) {
  if (samples.isEmpty) return const ExperimentalFaceSignalEvaluation();
  for (var i = 0; i < samples.length; i++) {
    final current = samples[i];
    if (current.capturedAt.isNegative || !current.sample.isValid) {
      return const ExperimentalFaceSignalEvaluation();
    }
    if (i > 0 && current.capturedAt <= samples[i - 1].capturedAt) {
      return const ExperimentalFaceSignalEvaluation();
    }
  }

  final conditions = _assessShootingConditions(samples, config);
  final colorFeature = _computeFaceColorFeature(samples, conditions, config);
  final rppg = _estimateRppg(samples, conditions, config);

  return ExperimentalFaceSignalEvaluation(
    faceColorFeature: colorFeature,
    shootingConditions: conditions,
    estimatedHeartRateBpm: rppg?.bpm,
    peakPowerRatio: rppg?.peakPowerRatio,
    prominenceRatio: rppg?.prominenceRatio,
    rppgAlgorithm: rppg == null ? null : config.rppgAlgorithm,
  );
}

ShootingConditionSummary _assessShootingConditions(
  List<TimedFaceRgbSample> samples,
  ExperimentalFaceSignalConfig config,
) {
  var sumLum = 0.0;
  var minLum = double.infinity;
  var maxLum = double.negativeInfinity;
  for (final item in samples) {
    final lum = item.sample.luminance;
    sumLum += lum;
    if (lum < minLum) minLum = lum;
    if (lum > maxLum) maxLum = lum;
  }
  final meanLum = sumLum / samples.length;
  var varianceSum = 0.0;
  for (final item in samples) {
    final diff = item.sample.luminance - meanLum;
    varianceSum += diff * diff;
  }
  final stdLum = sqrt(varianceSum / samples.length);
  final coeff = meanLum > 0 ? stdLum / meanLum : double.infinity;
  final stable =
      meanLum >= config.minLuminance &&
      meanLum <= config.maxLuminance &&
      minLum >= config.minLuminance &&
      maxLum <= config.maxLuminance &&
      coeff.isFinite &&
      coeff <= config.maxLuminanceVariationCoeff;

  final spanUs =
      samples.last.capturedAt.inMicroseconds -
      samples.first.capturedAt.inMicroseconds;
  final effectiveFps = spanUs > 0 && samples.length > 1
      ? ((samples.length - 1) * Duration.microsecondsPerSecond) / spanUs
      : 0.0;

  return ShootingConditionSummary(
    sampleCount: samples.length,
    meanLuminance: meanLum,
    minLuminance: minLum,
    maxLuminance: maxLum,
    luminanceVariationCoeff: coeff,
    isLightingStable: stable,
    effectiveFps: effectiveFps,
  );
}

double? _computeFaceColorFeature(
  List<TimedFaceRgbSample> samples,
  ShootingConditionSummary conditions,
  ExperimentalFaceSignalConfig config,
) {
  if (samples.length < config.minColorSamples || !conditions.isLightingStable) {
    return null;
  }
  final rednessValues = <double>[];
  for (final item in samples) {
    final redness = item.sample.normalizedRedness;
    if (redness == null) return null;
    rednessValues.add(redness);
  }
  rednessValues.sort();
  final middle = rednessValues.length ~/ 2;
  final median = rednessValues.length.isOdd
      ? rednessValues[middle]
      : (rednessValues[middle - 1] + rednessValues[middle]) / 2.0;
  return (median * 10000).roundToDouble() / 10000;
}

class _RppgInternalResult {
  const _RppgInternalResult({
    required this.bpm,
    required this.peakPowerRatio,
    required this.prominenceRatio,
  });

  final double bpm;
  final double peakPowerRatio;
  final double prominenceRatio;
}

_RppgInternalResult? _estimateRppg(
  List<TimedFaceRgbSample> samples,
  ShootingConditionSummary conditions,
  ExperimentalFaceSignalConfig config,
) {
  if (samples.length < config.minRppgSamples || !conditions.isLightingStable) {
    return null;
  }
  final span = samples.last.capturedAt - samples.first.capturedAt;
  if (span < config.minWindowDuration) return null;

  for (var i = 1; i < samples.length; i++) {
    if (samples[i].capturedAt - samples[i - 1].capturedAt >
        config.maxSampleGap) {
      return null;
    }
  }
  for (final item in samples) {
    final s = item.sample;
    if (s.red < 5 ||
        s.green < 5 ||
        s.blue < 5 ||
        s.red > 250 ||
        s.green > 250 ||
        s.blue > 250) {
      return null;
    }
  }

  const targetFs = 30.0;
  final spanSeconds = span.inMicroseconds / Duration.microsecondsPerSecond;
  final gridCount = (spanSeconds * targetFs).floor() + 1;
  if (gridCount < 90) return null;

  final rGrid = List<double>.filled(gridCount, 0);
  final gGrid = List<double>.filled(gridCount, 0);
  final bGrid = List<double>.filled(gridCount, 0);
  final startUs = samples.first.capturedAt.inMicroseconds;

  var cursor = 0;
  for (var i = 0; i < gridCount; i++) {
    final targetUs =
        startUs + (i * Duration.microsecondsPerSecond / targetFs).round();
    while (cursor + 1 < samples.length &&
        samples[cursor + 1].capturedAt.inMicroseconds < targetUs) {
      cursor++;
    }
    if (cursor + 1 >= samples.length) {
      final last = samples.last.sample;
      rGrid[i] = last.red;
      gGrid[i] = last.green;
      bGrid[i] = last.blue;
    } else {
      final left = samples[cursor];
      final right = samples[cursor + 1];
      final leftUs = left.capturedAt.inMicroseconds;
      final rightUs = right.capturedAt.inMicroseconds;
      final alpha = rightUs <= leftUs
          ? 0.0
          : ((targetUs - leftUs) / (rightUs - leftUs)).clamp(0.0, 1.0);
      rGrid[i] = left.sample.red + (right.sample.red - left.sample.red) * alpha;
      gGrid[i] =
          left.sample.green + (right.sample.green - left.sample.green) * alpha;
      bGrid[i] =
          left.sample.blue + (right.sample.blue - left.sample.blue) * alpha;
    }
  }

  final windowLen = (1.6 * targetFs).round();
  if (gridCount <= windowLen) return null;
  final pulse = List<double>.filled(gridCount, 0);
  final s1 = List<double>.filled(windowLen, 0);
  final s2 = List<double>.filled(windowLen, 0);

  for (var start = 0; start <= gridCount - windowLen; start++) {
    var meanR = 0.0;
    var meanG = 0.0;
    var meanB = 0.0;
    for (var k = 0; k < windowLen; k++) {
      meanR += rGrid[start + k];
      meanG += gGrid[start + k];
      meanB += bGrid[start + k];
    }
    meanR /= windowLen;
    meanG /= windowLen;
    meanB /= windowLen;
    if (meanR <= 0 || meanG <= 0 || meanB <= 0) return null;

    for (var k = 0; k < windowLen; k++) {
      final rn = rGrid[start + k] / meanR - 1.0;
      final gn = gGrid[start + k] / meanG - 1.0;
      final bn = bGrid[start + k] / meanB - 1.0;
      if (config.rppgAlgorithm == RppgAlgorithm.pos) {
        s1[k] = gn - bn;
        s2[k] = gn + bn - 2.0 * rn;
      } else {
        s1[k] = 3.0 * rn - 2.0 * gn;
        s2[k] = 1.5 * rn + gn - 1.5 * bn;
      }
    }

    final std1 = _stdDev(s1);
    final std2 = _stdDev(s2);
    if (!std1.isFinite || !std2.isFinite || std2 <= 1e-9) continue;
    final alpha = std1 / std2;
    var meanH = 0.0;
    final h = List<double>.filled(windowLen, 0);
    for (var k = 0; k < windowLen; k++) {
      h[k] = config.rppgAlgorithm == RppgAlgorithm.pos
          ? s1[k] + alpha * s2[k]
          : s1[k] - alpha * s2[k];
      meanH += h[k];
    }
    meanH /= windowLen;
    for (var k = 0; k < windowLen; k++) {
      pulse[start + k] += h[k] - meanH;
    }
  }

  _detrendLinear(pulse);
  final conditioned = _bandpassCondition(pulse, targetFs);
  final pulseStd = _stdDev(conditioned);
  if (!pulseStd.isFinite || pulseStd < 1e-5 || pulseStd > 1.0) {
    return null;
  }

  final windowed = List<double>.generate(conditioned.length, (i) {
    final hann = 0.5 * (1.0 - cos(2.0 * pi * i / (conditioned.length - 1)));
    return (conditioned[i] / pulseStd) * hann;
  });

  const stepBpm = 0.25;
  final numBins =
      ((config.maxHeartRateBpm - config.minHeartRateBpm) / stepBpm).round() + 1;
  if (numBins < 5) return null;

  final bpms = List<double>.filled(numBins, 0);
  final powers = List<double>.filled(numBins, 0);
  var totalPower = 0.0;
  var peakIdx = 0;
  var peakPower = -1.0;

  for (var b = 0; b < numBins; b++) {
    final bpm = config.minHeartRateBpm + b * stepBpm;
    final freqHz = bpm / 60.0;
    final omega = 2.0 * pi * freqHz / targetFs;
    var re = 0.0;
    var im = 0.0;
    for (var n = 0; n < windowed.length; n++) {
      final angle = omega * n;
      re += windowed[n] * cos(angle);
      im -= windowed[n] * sin(angle);
    }
    final power = (re * re + im * im) / windowed.length;
    bpms[b] = bpm;
    powers[b] = power;
    totalPower += power;
    if (power > peakPower) {
      peakPower = power;
      peakIdx = b;
    }
  }

  if (!totalPower.isFinite || totalPower <= 0 || peakPower <= 0) return null;
  if (peakIdx == 0 || peakIdx == numBins - 1) {
    // Reject peaks pinned to the boundary of the physiological search band.
    return null;
  }

  final peakBpm = bpms[peakIdx];
  var bandPower = 0.0;
  var secondPeakPower = 0.0;
  for (var b = 0; b < numBins; b++) {
    final diffBpm = (bpms[b] - peakBpm).abs();
    if (diffBpm <= 6.0) {
      bandPower += powers[b];
    } else if (diffBpm >= 9.0 && powers[b] > secondPeakPower) {
      secondPeakPower = powers[b];
    }
  }

  final peakPowerRatio = bandPower / totalPower;
  final prominenceRatio = secondPeakPower <= 1e-12
      ? double.infinity
      : peakPower / secondPeakPower;
  if (!peakPowerRatio.isFinite ||
      peakPowerRatio < config.minPeakPowerRatio ||
      prominenceRatio < config.minProminenceRatio) {
    return null;
  }

  final roundedBpm = (peakBpm * 10).roundToDouble() / 10;
  if (roundedBpm < config.minHeartRateBpm ||
      roundedBpm > config.maxHeartRateBpm) {
    return null;
  }

  return _RppgInternalResult(
    bpm: roundedBpm,
    peakPowerRatio: peakPowerRatio,
    prominenceRatio: prominenceRatio.isFinite ? prominenceRatio : 999.0,
  );
}

double _stdDev(List<double> values) {
  if (values.isEmpty) return 0;
  var mean = 0.0;
  for (final v in values) {
    mean += v;
  }
  mean /= values.length;
  var sumSq = 0.0;
  for (final v in values) {
    final d = v - mean;
    sumSq += d * d;
  }
  return sqrt(sumSq / values.length);
}

void _detrendLinear(List<double> values) {
  final n = values.length;
  if (n < 2) return;
  final meanX = (n - 1) / 2.0;
  var meanY = 0.0;
  for (final v in values) {
    meanY += v;
  }
  meanY /= n;
  var num = 0.0;
  var den = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = i - meanX;
    num += dx * (values[i] - meanY);
    den += dx * dx;
  }
  final slope = den > 0 ? num / den : 0.0;
  for (var i = 0; i < n; i++) {
    values[i] -= meanY + slope * (i - meanX);
  }
}

List<double> _bandpassCondition(List<double> values, double fs) {
  final n = values.length;
  final baselineRadius = (0.75 * fs).round().clamp(1, n ~/ 3);
  final highpassed = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final start = max(0, i - baselineRadius);
    final end = min(n - 1, i + baselineRadius);
    var sum = 0.0;
    for (var j = start; j <= end; j++) {
      sum += values[j];
    }
    highpassed[i] = values[i] - sum / (end - start + 1);
  }
  return highpassed;
}
