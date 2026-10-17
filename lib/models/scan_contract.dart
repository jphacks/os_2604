import 'health_check_result.dart';

enum ScanFailureReason {
  permissionDenied,
  faceNotFound,
  poorQuality,
  interrupted,
  cameraUnavailable,
  processingFailed,
}

enum ScanPhase {
  idle,
  requestingPermission,
  preparing,
  measuring,
  completed,
  failed,
}

enum ScanGuidance {
  faceNotFound,
  multipleFaces,
  missingData,
  lowLight,
  offAngle,
  offCenter,
  faceTooSmall,
  faceTooLarge,
  moving,
  noFrames,
}

sealed class ScanOutcome {
  const ScanOutcome();
}

final class ScanSuccess extends ScanOutcome {
  const ScanSuccess(this.result);
  final HealthCheckResult result;
}

final class ScanFailure extends ScanOutcome {
  const ScanFailure({required this.reason, required this.elapsed});
  final ScanFailureReason reason;

  /// Zero if measurement never started. Not a successful health record.
  final Duration elapsed;
}

class ScanProgress {
  const ScanProgress({
    required this.phase,
    this.elapsed = Duration.zero,
    this.guidance,
    this.failureReason,
  });
  final ScanPhase phase;
  final Duration elapsed;
  final ScanGuidance? guidance;
  final ScanFailureReason? failureReason;
  Duration get remaining {
    final value = HealthCheckResult.targetDuration - elapsed;
    return value.isNegative ? Duration.zero : value;
  }
}

abstract interface class HealthScanService {
  ScanProgress get currentProgress;
  Stream<ScanProgress> get progress;
  Future<ScanOutcome> startHealthScan();
  Future<void> cancelScan();
  Future<void> dispose();
}
