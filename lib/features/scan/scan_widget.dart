import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../models/scan_contract.dart';

/// Preview only. B owns start/retry buttons, progress/error text and navigation.
/// The owner must await service.dispose() when the scan screen is removed.
class ScanWidget extends StatefulWidget {
  const ScanWidget({
    super.key,
    required this.service,
    required this.preview,
    required this.placeholder,
    this.overlay,
  });
  final HealthScanService service;
  final ValueListenable<CameraController?> preview;
  final Widget placeholder;
  final Widget? overlay;

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScanWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      unawaited(oldWidget.service.cancelScan());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The first permission dialog is inactive, not an interrupted measurement.
    // Backgrounding still cancels, even while the user is deciding permission.
    if (state == AppLifecycleState.inactive &&
        widget.service.currentProgress.phase ==
            ScanPhase.requestingPermission) {
      return;
    }
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.service.cancelScan());
    }
  }

  @override
  void deactivate() {
    unawaited(widget.service.cancelScan());
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.service.cancelScan());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<CameraController?>(
        valueListenable: widget.preview,
        builder: (context, camera, child) =>
            camera == null || !camera.value.isInitialized
            ? widget.placeholder
            : ValueListenableBuilder<CameraValue>(
                valueListenable: camera,
                builder: (context, value, child) {
                  final orientation = value.isRecordingVideo
                      ? value.recordingOrientation
                      : (value.previewPauseOrientation ??
                            value.lockedCaptureOrientation ??
                            value.deviceOrientation);
                  final landscape =
                      orientation == DeviceOrientation.landscapeLeft ||
                      orientation == DeviceOrientation.landscapeRight;
                  return CameraPreviewViewport(
                    aspectRatio: landscape
                        ? value.aspectRatio
                        : 1 / value.aspectRatio,
                    child: CameraPreview(camera, child: widget.overlay),
                  );
                },
              ),
      );
}

/// Fill the guide by cropping, never by stretching the camera image.
class CameraPreviewViewport extends StatelessWidget {
  const CameraPreviewViewport({
    super.key,
    required this.aspectRatio,
    required this.child,
  });
  final double aspectRatio;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: aspectRatio * 1000, height: 1000, child: child),
    ),
  );
}
