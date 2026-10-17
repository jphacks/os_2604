import '../../models/scan_contract.dart';

class ScanObservation {
  const ScanObservation({required this.capturedAt, this.guidance});

  /// Captured before asynchronous inference using the service's monotonic clock.
  final Duration capturedAt;
  final ScanGuidance? guidance;
}

/// C-internal frame boundary. Implementations must not persist camera frames.
abstract interface class ScanFrameSource {
  Future<void> start({
    required Duration Function() monotonicNow,
    required void Function(ScanObservation) onObservation,
    required void Function(ScanFailureReason) onFailure,
  });
  Future<void> stop();
  Future<void> dispose();
}
