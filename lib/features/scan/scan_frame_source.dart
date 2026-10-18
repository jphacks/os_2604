import '../../models/scan_contract.dart';
import 'experimental_face_signals.dart';

class ScanObservation {
  const ScanObservation({
    required this.capturedAt,
    this.guidance,
    this.rgbSample,
    this.rgbSamples = const [],
  });

  /// Captured before asynchronous inference using the service's monotonic clock.
  final Duration capturedAt;
  final ScanGuidance? guidance;

  /// Optional in-memory facial skin RGB sample for the detected frame.
  final FaceRgbSample? rgbSample;

  /// High-frame-rate (e.g. 30fps) timestamped RGB samples captured across the
  /// current face-detection interval when decoupled P2 sampling is active.
  final List<TimedFaceRgbSample> rgbSamples;
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
