import 'dart:math' as math;

import '../../models/scan_contract.dart';
import 'scan_configuration.dart';

/// Normalized raw-buffer coordinates, not preview/screen coordinates.
class FaceGeometry {
  const FaceGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final double left;
  final double top;
  final double width;
  final double height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

ScanGuidance? assessFaceGeometry(
  FaceGeometry face,
  ScanConfiguration configuration, {
  FaceGeometry? previous,
  bool trackFace = false,
}) {
  if ([face.left, face.top, face.width, face.height].any((v) => !v.isFinite) ||
      face.width <= 0 ||
      face.height <= 0) {
    return ScanGuidance.missingData;
  }
  if (face.left < 0 ||
      face.top < 0 ||
      face.left + face.width > 1 ||
      face.top + face.height > 1 ||
      (!(trackFace && previous != null) &&
          ((face.centerX - 0.5).abs() > configuration.maxCenterOffset ||
              (face.centerY - 0.5).abs() > configuration.maxCenterOffset))) {
    return ScanGuidance.offCenter;
  }
  if (face.width < configuration.minFaceWidth) return ScanGuidance.faceTooSmall;
  if (face.width > configuration.maxFaceWidth) return ScanGuidance.faceTooLarge;
  // Once acquired, follow overlapping detections instead of treating bounding
  // box jitter as a quality failure. Partial faces still fail above. Require
  // substantial overlap so a sudden jump cannot be mistaken for continuity.
  if (trackFace && previous != null) {
    final width = math.max(
      0.0,
      math.min(face.left + face.width, previous.left + previous.width) -
          math.max(face.left, previous.left),
    );
    final height = math.max(
      0.0,
      math.min(face.top + face.height, previous.top + previous.height) -
          math.max(face.top, previous.top),
    );
    final intersection = width * height;
    final union =
        face.width * face.height +
        previous.width * previous.height -
        intersection;
    return intersection / union >= 0.6 ? null : ScanGuidance.moving;
  }
  if (previous != null &&
      ((face.centerX - previous.centerX).abs() >
              configuration.maxCenterMovement ||
          (face.centerY - previous.centerY).abs() >
              configuration.maxCenterMovement)) {
    return ScanGuidance.moving;
  }
  return null;
}
