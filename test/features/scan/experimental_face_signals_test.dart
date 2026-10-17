import 'dart:math';
import 'dart:typed_data';

import 'package:os_2604/features/scan/experimental_face_signals.dart';
import 'package:os_2604/features/scan/frame_luminance.dart';
import 'package:test/test.dart';

List<TimedFaceRgbSample> syntheticPulseSeries({
  double bpm = 72.0,
  int count = 451,
  Duration step = const Duration(microseconds: 33333),
  double baseR = 180.0,
  double baseG = 130.0,
  double baseB = 100.0,
  double pulseAmpR = 0.25,
  double pulseAmpG = 1.4,
  double pulseAmpB = 0.45,
  double commonIntensityModulation = 0.0,
  double noiseAmplitude = 0.0,
}) {
  final random = Random(42);
  final freqHz = bpm / 60.0;
  return List<TimedFaceRgbSample>.generate(count, (i) {
    final capturedAt = step * i;
    final tSec = capturedAt.inMicroseconds / Duration.microsecondsPerSecond;
    final phase = 2.0 * pi * freqHz * tSec;
    final pulse = sin(phase);
    // Common-mode illumination drift affects all channels proportionally.
    final commonScale =
        1.0 + commonIntensityModulation * sin(2.0 * pi * 0.25 * tSec);
    final noiseR = noiseAmplitude * (random.nextDouble() * 2.0 - 1.0);
    final noiseG = noiseAmplitude * (random.nextDouble() * 2.0 - 1.0);
    final noiseB = noiseAmplitude * (random.nextDouble() * 2.0 - 1.0);
    return TimedFaceRgbSample(
      capturedAt: capturedAt,
      sample: FaceRgbSample(
        red: (baseR * commonScale + pulseAmpR * pulse + noiseR).clamp(
          0.0,
          255.0,
        ),
        green: (baseG * commonScale + pulseAmpG * pulse + noiseG).clamp(
          0.0,
          255.0,
        ),
        blue: (baseB * commonScale + pulseAmpB * pulse + noiseB).clamp(
          0.0,
          255.0,
        ),
      ),
    );
  });
}

void main() {
  test(
    'extractSkinRoiRegion selects inner skin area and rejects invalid boxes',
    () {
      final roi = extractSkinRoiRegion(
        const FrameRegion(left: 10, top: 20, width: 100, height: 120),
      );
      expect(roi, isNotNull);
      expect(roi!.left, 35);
      expect(roi.top, 50);
      expect(roi.width, 50);
      expect(roi.height, 60);

      // Small synthetic face bounding box stays valid and non-empty.
      final smallRoi = extractSkinRoiRegion(
        const FrameRegion(left: 3, top: 2, width: 4, height: 6),
      );
      expect(smallRoi, isNotNull);
      expect(smallRoi!.left, greaterThanOrEqualTo(3));
      expect(smallRoi.top, greaterThanOrEqualTo(2));
      expect(smallRoi.left + smallRoi.width, lessThanOrEqualTo(7));
      expect(smallRoi.top + smallRoi.height, lessThanOrEqualTo(8));

      expect(
        extractSkinRoiRegion(
          const FrameRegion(left: -1, top: 0, width: 4, height: 4),
        ),
        isNull,
      );
      expect(
        extractSkinRoiRegion(
          const FrameRegion(left: 0, top: 0, width: 0, height: 4),
        ),
        isNull,
      );
    },
  );

  test('downsampleBgra8888ForDetection and stabilizeFaceRegion preserve 30fps ROI stability', () {
    final small = Uint8List(10 * 10 * 4);
    final unchanged = downsampleBgra8888ForDetection(
      bytes: small,
      width: 10,
      height: 10,
      bytesPerRow: 40,
      factor: 4,
    );
    expect(unchanged.width, 10);
    expect(unchanged.height, 10);
    expect(unchanged.scaleX, 1.0);

    final hd = Uint8List(640 * 360 * 4);
    final downsampled = downsampleBgra8888ForDetection(
      bytes: hd,
      width: 640,
      height: 360,
      bytesPerRow: 640 * 4,
      factor: 4,
    );
    expect(downsampled.width, 160);
    expect(downsampled.height, 90);
    expect(downsampled.scaleX, 4.0);
    expect(downsampled.scaleY, 4.0);

    const base = FrameRegion(left: 200, top: 200, width: 300, height: 400);
    const jittered = FrameRegion(left: 202, top: 199, width: 302, height: 398);
    expect(stabilizeFaceRegion(jittered, previous: base), same(base));

    const shifted = FrameRegion(left: 230, top: 200, width: 300, height: 400);
    expect(stabilizeFaceRegion(shifted, previous: base), same(shifted));
  });

  test(
    'sampleFaceRgbBgra8888 reads BGRA channels and excludes outer border',
    () {
      final bytes = Uint8List(4 * 4 * 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final offset = (y * 4 + x) * 4;
          final isInner = x >= 1 && x <= 2 && y >= 1 && y <= 2;
          bytes[offset] = isInner ? 80 : 255; // B
          bytes[offset + 1] = isInner ? 120 : 255; // G
          bytes[offset + 2] = isInner ? 200 : 255; // R
          bytes[offset + 3] = 255; // A
        }
      }

      final sample = sampleFaceRgbBgra8888(
        bytes: bytes,
        width: 4,
        height: 4,
        bytesPerRow: 16,
        faceRegion: const FrameRegion(left: 0, top: 0, width: 4, height: 4),
      );
      expect(sample, isNotNull);
      expect(sample!.red, closeTo(200, 0.0001));
      expect(sample.green, closeTo(120, 0.0001));
      expect(sample.blue, closeTo(80, 0.0001));
      expect(sample.normalizedRedness, closeTo(0.5, 0.0001));
    },
  );

  test(
    'sampleFaceRgbBgra8888 rejects malformed buffers and overflow metadata',
    () {
      const huge = 0x7fffffffffffffff;
      final validBytes = Uint8List.fromList([80, 120, 200, 255]);
      expect(
        sampleFaceRgbBgra8888(
          bytes: Uint8List(3),
          width: 1,
          height: 1,
          bytesPerRow: 4,
          faceRegion: const FrameRegion(left: 0, top: 0, width: 1, height: 1),
        ),
        isNull,
      );
      expect(
        sampleFaceRgbBgra8888(
          bytes: validBytes,
          width: huge,
          height: 1,
          bytesPerRow: 4,
          faceRegion: const FrameRegion(left: 0, top: 0, width: 1, height: 1),
        ),
        isNull,
      );
      expect(
        sampleFaceRgbBgra8888(
          bytes: validBytes,
          width: 1,
          height: 1,
          bytesPerRow: 4,
          faceRegion: const FrameRegion(left: 0, top: 0, width: 2, height: 1),
        ),
        isNull,
      );
    },
  );

  test('faceColorFeature normalizes brightness scale and rejects unstable lighting', () {
    final config = ExperimentalFaceSignalConfig();
    final dimmer = syntheticPulseSeries(
      baseR: 150,
      baseG: 100,
      baseB: 50,
      pulseAmpR: 0,
      pulseAmpG: 0,
      pulseAmpB: 0,
    );
    final brighter = syntheticPulseSeries(
      baseR: 180,
      baseG: 120,
      baseB: 60,
      pulseAmpR: 0,
      pulseAmpG: 0,
      pulseAmpB: 0,
    );
    final evalDimmer = evaluateExperimentalFaceSignals(dimmer, config);
    final evalBrighter = evaluateExperimentalFaceSignals(brighter, config);

    expect(evalDimmer.shootingConditions?.isLightingStable, isTrue);
    expect(evalDimmer.shootingConditions?.effectiveFps, closeTo(30.0, 0.1));
    expect(evalDimmer.faceColorFeature, closeTo(0.5, 0.0001));
    expect(evalBrighter.faceColorFeature, closeTo(0.5, 0.0001));

    final unstable = syntheticPulseSeries(
      commonIntensityModulation: 0.35,
      pulseAmpR: 0,
      pulseAmpG: 0,
      pulseAmpB: 0,
    );
    final evalUnstable = evaluateExperimentalFaceSignals(unstable, config);
    expect(evalUnstable.shootingConditions?.isLightingStable, isFalse);
    expect(evalUnstable.faceColorFeature, isNull);
    expect(evalUnstable.estimatedHeartRateBpm, isNull);
  });

  for (final algorithm in RppgAlgorithm.values) {
    test(
      '15-second 30fps rPPG ($algorithm) estimates clean physiological pulse',
      () {
        final config = ExperimentalFaceSignalConfig(rppgAlgorithm: algorithm);
        for (final targetBpm in [60.0, 72.0, 90.0]) {
          final samples = syntheticPulseSeries(
            bpm: targetBpm,
            commonIntensityModulation: 0.02,
          );
          final evaluation = evaluateExperimentalFaceSignals(samples, config);
          expect(evaluation.estimatedHeartRateBpm, isNotNull);
          expect(evaluation.estimatedHeartRateBpm!, closeTo(targetBpm, 1.0));
          expect(evaluation.rppgAlgorithm, algorithm);
          expect(evaluation.faceColorFeature, isNotNull);
        }
      },
    );
  }

  test('flatline, noisy or out-of-band signals return null BPM without dummy values', () {
    final config = ExperimentalFaceSignalConfig();

    final flatline = syntheticPulseSeries(
      pulseAmpR: 0,
      pulseAmpG: 0,
      pulseAmpB: 0,
    );
    final flatEval = evaluateExperimentalFaceSignals(flatline, config);
    expect(flatEval.estimatedHeartRateBpm, isNull);
    expect(flatEval.faceColorFeature, isNotNull);

    final noisy = syntheticPulseSeries(
      bpm: 72,
      pulseAmpR: 0.05,
      pulseAmpG: 0.1,
      pulseAmpB: 0.05,
      noiseAmplitude: 4.0,
    );
    final noisyEval = evaluateExperimentalFaceSignals(noisy, config);
    expect(noisyEval.estimatedHeartRateBpm, isNull);

    final outOfBand = syntheticPulseSeries(bpm: 30.0);
    final outOfBandEval = evaluateExperimentalFaceSignals(outOfBand, config);
    expect(outOfBandEval.estimatedHeartRateBpm, isNull);
  });

  test(
    'short window or frame gap rejects rPPG while keeping valid color feature',
    () {
      final config = ExperimentalFaceSignalConfig();
      final shortSeries = syntheticPulseSeries(
        count: 120,
        step: const Duration(milliseconds: 100),
      ); // 11.9 seconds < 14s
      final shortEval = evaluateExperimentalFaceSignals(shortSeries, config);
      expect(shortEval.estimatedHeartRateBpm, isNull);
      expect(shortEval.faceColorFeature, isNotNull);

      final gapped = syntheticPulseSeries(
        count: 151,
        step: const Duration(milliseconds: 100),
      );
      gapped.removeAt(50);
      gapped.removeAt(50);
      gapped.removeAt(50);
      gapped.removeAt(50);
      gapped.removeAt(50); // Creates a 600ms gap (> 500ms limit).
      final gappedEval = evaluateExperimentalFaceSignals(gapped, config);
      expect(gappedEval.estimatedHeartRateBpm, isNull);
    },
  );

  test('invalid experimental config parameters throw ArgumentError', () {
    expect(
      () => ExperimentalFaceSignalConfig(minColorSamples: 0),
      throwsArgumentError,
    );
    expect(
      () => ExperimentalFaceSignalConfig(minRppgSamples: 10),
      throwsArgumentError,
    );
    expect(
      () => ExperimentalFaceSignalConfig(
        minHeartRateBpm: 180,
        maxHeartRateBpm: 60,
      ),
      throwsArgumentError,
    );
    expect(
      () => ExperimentalFaceSignalConfig(minPeakPowerRatio: 1.2),
      throwsArgumentError,
    );
  });
}
