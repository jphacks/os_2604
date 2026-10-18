import 'experimental_face_signals.dart';
import 'frame_signal_quality.dart';

class ScanConfiguration {
  ScanConfiguration({
    required this.signals,
    required this.maxCenterOffset,
    required this.minFaceWidth,
    required this.maxFaceWidth,
    required this.maxCenterMovement,
    required this.preparationStability,
    required this.maxObservationGap,
    this.experimentalSignals,
  }) {
    for (final value in [
      maxCenterOffset,
      minFaceWidth,
      maxFaceWidth,
      maxCenterMovement,
    ]) {
      if (!value.isFinite || value < 0 || value > 1) {
        throw ArgumentError('Normalized geometry limits must be in 0..1.');
      }
    }
    if (minFaceWidth <= 0 ||
        minFaceWidth >= maxFaceWidth ||
        maxCenterOffset > 0.5 ||
        preparationStability.isNegative ||
        maxObservationGap <= Duration.zero) {
      throw ArgumentError('Invalid scan configuration.');
    }
  }

  /// Approved on 2026-10-17 for device calibration; not validated accuracy.
  /// Keeps P2 experimental features disabled by default to preserve P0/P1.
  factory ScanConfiguration.day1Trial({
    ExperimentalFaceSignalConfig? experimentalSignals,
  }) => ScanConfiguration(
    signals: FrameSignalLimits(
      minLuminance: 50,
      maxAbsPitch: 15,
      maxAbsYaw: 20,
      maxAbsRoll: 10,
    ),
    maxCenterOffset: 0.2,
    minFaceWidth: 0.2,
    maxFaceWidth: 0.8,
    maxCenterMovement: 0.05,
    preparationStability: const Duration(milliseconds: 500),
    maxObservationGap: const Duration(milliseconds: 500),
    experimentalSignals: experimentalSignals,
  );

  /// Opt-in P2 verification configuration for facial color and 15s rPPG.
  factory ScanConfiguration.day1Experimental({
    RppgAlgorithm rppgAlgorithm = RppgAlgorithm.pos,
    ExperimentalFaceSignalConfig? experimentalSignals,
  }) => ScanConfiguration.day1Trial(
    experimentalSignals:
        experimentalSignals ??
        ExperimentalFaceSignalConfig(rppgAlgorithm: rppgAlgorithm),
  );

  final FrameSignalLimits signals;
  final double maxCenterOffset;
  final double minFaceWidth;
  final double maxFaceWidth;
  final double maxCenterMovement;
  final Duration preparationStability;
  final Duration maxObservationGap;

  /// Null in standard P0/P1 mode. Set only in P2 experimental verification.
  final ExperimentalFaceSignalConfig? experimentalSignals;
}
