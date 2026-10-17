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
      (face.centerX - 0.5).abs() > configuration.maxCenterOffset ||
      (face.centerY - 0.5).abs() > configuration.maxCenterOffset) {
    return ScanGuidance.offCenter;
  }
  if (face.width < configuration.minFaceWidth) return ScanGuidance.faceTooSmall;
  if (face.width > configuration.maxFaceWidth) return ScanGuidance.faceTooLarge;
  if (previous != null &&
      ((face.centerX - previous.centerX).abs() >
              configuration.maxCenterMovement ||
          (face.centerY - previous.centerY).abs() >
              configuration.maxCenterMovement)) {
    return ScanGuidance.moving;
  }
  return null;
}
