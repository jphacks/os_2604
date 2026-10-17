import 'package:test/test.dart';

import '../../../lib/features/scan/frame_signal_quality.dart';

void main() {
  // Synthetic test limits, not product thresholds.
  final limits = FrameSignalLimits(
    minLuminance: 50,
    maxAbsPitch: 15,
    maxAbsYaw: 20,
    maxAbsRoll: 10,
  );

  FrameSignalIssue? assess({
    int faceCount = 1,
    double? luminance = 100,
    double? pitch = 0,
    double? yaw = 0,
    double? roll = 0,
  }) => assessFrameSignals(
    faceCount: faceCount,
    luminance: luminance,
    pitch: pitch,
    yaw: yaw,
    roll: roll,
    limits: limits,
  );

  test('face absence and multiple faces are distinct', () {
    expect(assess(faceCount: 0), FrameSignalIssue.noFace);
    expect(assess(faceCount: 2), FrameSignalIssue.multipleFaces);
    expect(assess(faceCount: -1), FrameSignalIssue.missingData);
  });

  test('missing, non-finite and out-of-range signals never pass', () {
    for (final value in [null, double.nan, double.infinity, -1.0, 256.0]) {
      expect(assess(luminance: value), FrameSignalIssue.missingData);
    }
    for (final value in [null, double.nan, double.infinity, -181.0, 181.0]) {
      expect(assess(pitch: value), FrameSignalIssue.missingData);
      expect(assess(yaw: value), FrameSignalIssue.missingData);
      expect(assess(roll: value), FrameSignalIssue.missingData);
    }
  });

  test('measured darkness fails the light check', () {
    expect(assess(luminance: 0), FrameSignalIssue.lowLight);
    expect(assess(luminance: 49.9), FrameSignalIssue.lowLight);
    expect(assess(luminance: 50), isNull);
  });

  test('angles are checked in both directions at explicit boundaries', () {
    expect(assess(pitch: 15, yaw: -20, roll: 10), isNull);
    expect(assess(pitch: -15, yaw: 20, roll: -10), isNull);
    expect(assess(pitch: 15.1), FrameSignalIssue.offAngle);
    expect(assess(pitch: -15.1), FrameSignalIssue.offAngle);
    expect(assess(yaw: 20.1), FrameSignalIssue.offAngle);
    expect(assess(yaw: -20.1), FrameSignalIssue.offAngle);
    expect(assess(roll: 10.1), FrameSignalIssue.offAngle);
    expect(assess(roll: -10.1), FrameSignalIssue.offAngle);
  });

  test('invalid configuration fails immediately without assertions', () {
    for (final value in [double.nan, double.infinity, -1.0, 256.0]) {
      expect(
        () => FrameSignalLimits(
          minLuminance: value,
          maxAbsPitch: 15,
          maxAbsYaw: 20,
          maxAbsRoll: 10,
        ),
        throwsArgumentError,
      );
    }
    for (final value in [double.nan, double.infinity, -1.0, 181.0]) {
      for (var axis = 0; axis < 3; axis++) {
        expect(
          () => FrameSignalLimits(
            minLuminance: 50,
            maxAbsPitch: axis == 0 ? value : 15,
            maxAbsYaw: axis == 1 ? value : 20,
            maxAbsRoll: axis == 2 ? value : 10,
          ),
          throwsArgumentError,
        );
      }
    }
  });
}
