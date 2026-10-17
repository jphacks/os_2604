import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'health_scan_controller.dart';
import 'ios_camera_frame_source.dart';
import 'ios_camera_permission_gate.dart';
import 'scan_configuration.dart';

class CameraScanService extends HealthScanController {
  factory CameraScanService({ScanConfiguration? configuration}) {
    final selected = configuration ?? ScanConfiguration.day1Trial();
    return CameraScanService._(IosCameraFrameSource(selected), selected);
  }

  CameraScanService._(this._cameraSource, ScanConfiguration configuration)
    : super(
        source: _cameraSource,
        configuration: configuration,
        permissionGate: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? IosCameraPermissionGate()
            : null,
      );

  final IosCameraFrameSource _cameraSource;
  ValueListenable<CameraController?> get preview => _cameraSource.preview;
}
