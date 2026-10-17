import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
            : CameraPreview(camera, child: widget.overlay),
      );
}
