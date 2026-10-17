import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/scan_contract.dart';
import 'face_geometry.dart';
import 'frame_luminance.dart';
import 'frame_signal_quality.dart';
import 'scan_configuration.dart';
import 'scan_frame_source.dart';

/// iOS first, matching the available team devices. No Android support claim.
class IosCameraFrameSource implements ScanFrameSource {
  IosCameraFrameSource(this.configuration);
  final ScanConfiguration configuration;
  final ValueNotifier<CameraController?> _preview = ValueNotifier(null);
  ValueListenable<CameraController?> get preview => _preview;
  CameraController? _camera;
  FaceDetector? _detector;
  FaceGeometry? _previousFace;
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  Future<void> start({
    required Duration Function() monotonicNow,
    required void Function(ScanObservation) onObservation,
    required void Function(ScanFailureReason) onFailure,
  }) async {
    if (_disposed || _camera != null) {
      throw StateError('Camera is unavailable.');
    }
    final generation = ++_generation;
    _previousFace = null;
    _busy = false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      onFailure(ScanFailureReason.cameraUnavailable);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (generation != _generation) return;
      final front = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty) {
        onFailure(ScanFailureReason.cameraUnavailable);
        return;
      }
      final camera = CameraController(
        front.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      _camera = camera;
      await camera.initialize();
      if (generation != _generation) return;
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (generation != _generation) return;
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      _detector = detector;
      _preview.value = camera;
      camera.addListener(() {
        if (generation == _generation && camera.value.hasError) {
          onFailure(ScanFailureReason.cameraUnavailable);
        }
      });
      final streamStarted = Completer<void>();
      // camera's stream listener does not expose an onError callback. Keep
      // native stream errors inside this session instead of the app's root zone.
      runZonedGuarded(
        () {
          unawaited(
            camera
                .startImageStream((image) {
                  if (generation != _generation || _busy) return;
                  _busy = true;
                  final capturedAt = monotonicNow();
                  unawaited(
                    _process(
                      image,
                      detector,
                      generation,
                      capturedAt,
                      onObservation,
                      onFailure,
                    ),
                  );
                })
                .then<void>(
                  (_) => streamStarted.complete(),
                  onError: (Object error, StackTrace stack) =>
                      streamStarted.completeError(error, stack),
                ),
          );
        },
        (Object error, StackTrace stack) {
          if (generation == _generation) {
            onFailure(ScanFailureReason.processingFailed);
          }
        },
      );
      await streamStarted.future;
    } on CameraException catch (error) {
      if (generation != _generation) return;
      onFailure(switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => ScanFailureReason.permissionDenied,
        _ => ScanFailureReason.cameraUnavailable,
      });
    } on Object {
      if (generation == _generation) {
        onFailure(ScanFailureReason.cameraUnavailable);
      }
    }
  }

  Future<void> _process(
    CameraImage image,
    FaceDetector detector,
    int generation,
    Duration capturedAt,
    void Function(ScanObservation) onObservation,
    void Function(ScanFailureReason) onFailure,
  ) async {
    try {
      if (image.format.group != ImageFormatGroup.bgra8888 ||
          image.planes.length != 1 ||
          image.width <= 0 ||
          image.height <= 0) {
        throw StateError('Unsupported camera buffer.');
      }
      final plane = image.planes.single;
      // Validate before passing a native buffer; ML Kit reads full padded rows.
      if (plane.bytesPerRow < image.width * 4 ||
          image.height > plane.bytes.length ~/ plane.bytesPerRow) {
        throw StateError('Invalid camera buffer.');
      }
      // The selected iOS plugin constructs an upright UIImage from these bytes
      // and ignores metadata.rotation. Its face rectangles use raw-buffer axes.
      // Keep sampling and normalized geometry in that same coordinate system.
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final faces = await detector.processImage(input);
      if (generation != _generation) return;
      ScanGuidance? guidance;
      if (faces.length != 1) {
        _previousFace = null;
        guidance = faces.isEmpty
            ? ScanGuidance.faceNotFound
            : ScanGuidance.multipleFaces;
      } else {
        final face = faces.single;
        final rect = face.boundingBox;
        final geometry = FaceGeometry(
          left: rect.left / image.width,
          top: rect.top / image.height,
          width: rect.width / image.width,
          height: rect.height / image.height,
        );
        guidance = assessFaceGeometry(
          geometry,
          configuration,
          previous: _previousFace,
        );
        _previousFace = geometry;
        if (guidance == null) {
          final luminance = meanFrameLuminance(
            bytes: plane.bytes,
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            format: LuminanceFormat.bgra8888,
            region: FrameRegion(
              left: rect.left.floor(),
              top: rect.top.floor(),
              width: rect.right.ceil() - rect.left.floor(),
              height: rect.bottom.ceil() - rect.top.floor(),
            ),
          );
          final signalIssue = assessFrameSignals(
            faceCount: 1,
            luminance: luminance,
            pitch: face.headEulerAngleX,
            yaw: face.headEulerAngleY,
            roll: face.headEulerAngleZ,
            limits: configuration.signals,
          );
          guidance = switch (signalIssue) {
            null => null,
            FrameSignalIssue.noFace => ScanGuidance.faceNotFound,
            FrameSignalIssue.multipleFaces => ScanGuidance.multipleFaces,
            FrameSignalIssue.missingData => ScanGuidance.missingData,
            FrameSignalIssue.lowLight => ScanGuidance.lowLight,
            FrameSignalIssue.offAngle => ScanGuidance.offAngle,
          };
        }
      }
      onObservation(
        ScanObservation(capturedAt: capturedAt, guidance: guidance),
      );
    } on Object {
      if (generation == _generation) {
        onFailure(ScanFailureReason.processingFailed);
      }
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _previousFace = null;
    final camera = _camera;
    final detector = _detector;
    _camera = null;
    _detector = null;
    _preview.value = null;
    try {
      if (camera != null) {
        try {
          if (camera.value.isStreamingImages) await camera.stopImageStream();
        } finally {
          await camera.dispose();
        }
      }
    } finally {
      // Pending inference may finish later; its generation can no longer emit.
      await detector?.close();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await stop();
    } finally {
      _preview.dispose();
    }
  }
}
