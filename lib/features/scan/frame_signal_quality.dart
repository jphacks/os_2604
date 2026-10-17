/// Per-frame signal checks only. Passing does not establish scan validity:
/// position, motion, observation continuity and the 15-second session are separate.
enum FrameSignalIssue { noFace, multipleFaces, missingData, lowLight, offAngle }

/// No product defaults: limits must be agreed and checked on the target device.
class FrameSignalLimits {
  FrameSignalLimits({
    required this.minLuminance,
    required this.maxAbsPitch,
    required this.maxAbsYaw,
    required this.maxAbsRoll,
  }) {
    _validate(minLuminance, 255, 'minLuminance');
    _validate(maxAbsPitch, 180, 'maxAbsPitch');
    _validate(maxAbsYaw, 180, 'maxAbsYaw');
    _validate(maxAbsRoll, 180, 'maxAbsRoll');
  }

  final double minLuminance;
  final double maxAbsPitch;
  final double maxAbsYaw;
  final double maxAbsRoll;

  static void _validate(double value, double upper, String name) {
    if (!value.isFinite || value < 0 || value > upper) {
      throw ArgumentError.value(value, name, 'must be finite and in 0..$upper');
    }
  }
}

/// Null means these signal checks passed, not that a scan can be saved.
/// Missing/non-finite measurements are never replaced with normal values.
FrameSignalIssue? assessFrameSignals({
  required int faceCount,
  required double? luminance,
  required double? pitch,
  required double? yaw,
  required double? roll,
  required FrameSignalLimits limits,
}) {
  if (faceCount < 0) return FrameSignalIssue.missingData;
  if (faceCount == 0) return FrameSignalIssue.noFace;
  if (faceCount > 1) return FrameSignalIssue.multipleFaces;
  if (luminance == null ||
      !luminance.isFinite ||
      luminance < 0 ||
      luminance > 255 ||
      pitch == null ||
      !pitch.isFinite ||
      pitch.abs() > 180 ||
      yaw == null ||
      !yaw.isFinite ||
      yaw.abs() > 180 ||
      roll == null ||
      !roll.isFinite ||
      roll.abs() > 180) {
    return FrameSignalIssue.missingData;
  }
  if (luminance < limits.minLuminance) return FrameSignalIssue.lowLight;
  if (pitch.abs() > limits.maxAbsPitch ||
      yaw.abs() > limits.maxAbsYaw ||
      roll.abs() > limits.maxAbsRoll) {
    return FrameSignalIssue.offAngle;
  }
  return null;
}
