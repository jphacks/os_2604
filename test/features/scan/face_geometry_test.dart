import 'package:test/test.dart';

import 'package:os_2604/features/scan/face_geometry.dart';
import 'package:os_2604/features/scan/scan_configuration.dart';
import 'package:os_2604/models/scan_contract.dart';

void main() {
  final configuration = ScanConfiguration.day1Trial();
  const center = FaceGeometry(left: 0.3, top: 0.2, width: 0.4, height: 0.6);
  test('centered face passes geometry', () {
    expect(assessFaceGeometry(center, configuration), isNull);
  });
  test('invalid, partial and off-center faces cannot pass', () {
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: double.nan, top: 0.2, width: 0.4, height: 0.6),
        configuration,
      ),
      ScanGuidance.missingData,
    );
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: -0.1, top: 0.2, width: 0.4, height: 0.6),
        configuration,
      ),
      ScanGuidance.offCenter,
    );
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.7, top: 0.2, width: 0.2, height: 0.6),
        configuration,
      ),
      ScanGuidance.offCenter,
    );
  });
  test('face width has both a lower and upper limit', () {
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.45, top: 0.2, width: 0.1, height: 0.6),
        configuration,
      ),
      ScanGuidance.faceTooSmall,
    );
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.05, top: 0.2, width: 0.9, height: 0.6),
        configuration,
      ),
      ScanGuidance.faceTooLarge,
    );
  });
  test('movement is checked on both normalized axes', () {
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.36, top: 0.2, width: 0.4, height: 0.6),
        configuration,
        previous: center,
      ),
      ScanGuidance.moving,
    );
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.3, top: 0.26, width: 0.4, height: 0.6),
        configuration,
        previous: center,
      ),
      ScanGuidance.moving,
    );
    expect(assessFaceGeometry(center, configuration, previous: center), isNull);
  });
  test('tracking follows gradual motion beyond initial alignment', () {
    var previous = center;
    for (final left in [0.36, 0.42, 0.48, 0.54]) {
      final face = FaceGeometry(left: left, top: 0.2, width: 0.4, height: 0.6);
      expect(
        assessFaceGeometry(
          face,
          configuration,
          previous: previous,
          trackFace: true,
        ),
        isNull,
      );
      previous = face;
    }
    expect(assessFaceGeometry(previous, configuration), ScanGuidance.offCenter);
  });
  test('tracking rejects abrupt jumps, cropped faces and invalid sizes', () {
    for (final face in [
      const FaceGeometry(left: 0.55, top: 0.2, width: 0.4, height: 0.6),
      const FaceGeometry(left: 0.65, top: 0.2, width: 0.4, height: 0.6),
      const FaceGeometry(left: 0.45, top: 0.2, width: 0.1, height: 0.6),
    ]) {
      expect(
        assessFaceGeometry(
          face,
          configuration,
          previous: center,
          trackFace: true,
        ),
        isNotNull,
      );
    }
    expect(
      assessFaceGeometry(
        const FaceGeometry(left: 0.54, top: 0.2, width: 0.4, height: 0.6),
        configuration,
        trackFace: true,
      ),
      ScanGuidance.offCenter,
    );
  });
}
