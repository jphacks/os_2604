import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/scan_contract.dart';
import 'experimental_face_signals.dart';
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
  int? _trackingId;
  FrameRegion? _lastValidFaceRegion;
  Duration? _lastDetectionAt;
  final List<TimedFaceRgbSample> _pendingRgbSamples = [];
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
    _trackingId = null;
    _lastValidFaceRegion = null;
    _lastDetectionAt = null;
    _pendingRgbSamples.clear();
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
      if (configuration.experimentalSignals != null) {
        try {
          await camera.setExposureMode(ExposureMode.locked);
        } on Object {
          // Best-effort exposure stabilization; unsupported mocks/devices continue.
        }
        if (generation != _generation) return;
      }
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableTracking: true,
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
                  if (generation != _generation) return;
                  final capturedAt = monotonicNow();
                  final experimentalConfig = configuration.experimentalSignals;
                  final canThrottleDetection =
                      experimentalConfig != null &&
                      _lastValidFaceRegion != null &&
                      _lastDetectionAt != null &&
                      capturedAt > _lastDetectionAt! &&
                      capturedAt - _lastDetectionAt! <
                          experimentalConfig.faceDetectionInterval;
                  if (_busy || canThrottleDetection) {
                    if (experimentalConfig != null &&
                        _lastValidFaceRegion != null) {
                      _sampleIntermediateRgb(
                        image,
                        capturedAt,
                        _lastValidFaceRegion!,
                      );
                    }
                    return;
                  }
                  _busy = true;
                  _lastDetectionAt = capturedAt;
                  final priorSamples = List<TimedFaceRgbSample>.of(
                    _pendingRgbSamples,
                  );
                  _pendingRgbSamples.clear();
                  unawaited(
                    _process(
                      image,
                      detector,
                      generation,
                      capturedAt,
                      priorSamples,
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

  void _sampleIntermediateRgb(
    CameraImage image,
    Duration capturedAt,
    FrameRegion faceRegion,
  ) {
    if (image.format.group != ImageFormatGroup.bgra8888 ||
        image.planes.length != 1 ||
        image.width <= 0 ||
        image.height <= 0) {
      return;
    }
    final plane = image.planes.single;
    if (plane.bytesPerRow < image.width * 4 ||
        image.height > plane.bytes.length ~/ plane.bytesPerRow) {
      return;
    }
    final sample = sampleFaceRgbBgra8888(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      faceRegion: faceRegion,
    );
    if (sample == null) return;
    if (_pendingRgbSamples.isEmpty ||
        capturedAt > _pendingRgbSamples.last.capturedAt) {
      _pendingRgbSamples.add(
        TimedFaceRgbSample(capturedAt: capturedAt, sample: sample),
      );
    }
  }

  Future<void> _process(
    CameraImage image,
    FaceDetector detector,
    int generation,
    Duration capturedAt,
    List<TimedFaceRgbSample> priorSamples,
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
      final experimentalConfig = configuration.experimentalSignals;
      final detectionFrame = downsampleBgra8888ForDetection(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
        factor: experimentalConfig?.faceDetectionDownsampleFactor ?? 1,
      );
      // The selected iOS plugin constructs an upright UIImage from these bytes
      // and ignores metadata.rotation. Its face rectangles use raw-buffer axes.
      // Keep sampling and normalized geometry in that same coordinate system.
      final input = InputImage.fromBytes(
        bytes: detectionFrame.bytes,
        metadata: InputImageMetadata(
          size: Size(
            detectionFrame.width.toDouble(),
            detectionFrame.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: detectionFrame.bytesPerRow,
        ),
      );
      final faces = await detector.processImage(input);
      if (generation != _generation) return;
      ScanGuidance? guidance;
      FaceRgbSample? rgbSample;
      var batchSamples = const <TimedFaceRgbSample>[];
      if (faces.length != 1) {
        _previousFace = null;
        _trackingId = null;
        _lastValidFaceRegion = null;
        _pendingRgbSamples.clear();
        guidance = faces.isEmpty
            ? ScanGuidance.faceNotFound
            : ScanGuidance.multipleFaces;
      } else {
        final face = faces.single;
        final rect = face.boundingBox;
        final geometry = FaceGeometry(
          left: rect.left / detectionFrame.width,
          top: rect.top / detectionFrame.height,
          width: rect.width / detectionFrame.width,
          height: rect.height / detectionFrame.height,
        );
        final trackChanged =
            _trackingId != null && face.trackingId != _trackingId;
        if (trackChanged) {
          // A new track must satisfy initial alignment again.
          _previousFace = null;
          _lastValidFaceRegion = null;
          _pendingRgbSamples.clear();
        }
        _trackingId = face.trackingId;
        guidance = assessFaceGeometry(
          geometry,
          configuration,
          previous: _previousFace,
          trackFace: true,
        );
        if (trackChanged) guidance = ScanGuidance.moving;
        _previousFace = guidance == null ? geometry : null;
        if (guidance != null) {
          _lastValidFaceRegion = null;
          _pendingRgbSamples.clear();
        } else {
          final rawLeft = (rect.left * detectionFrame.scaleX).floor().clamp(
            0,
            image.width - 1,
          );
          final rawTop = (rect.top * detectionFrame.scaleY).floor().clamp(
            0,
            image.height - 1,
          );
          final rawRight = (rect.right * detectionFrame.scaleX).ceil().clamp(
            rawLeft + 1,
            image.width,
          );
          final rawBottom = (rect.bottom * detectionFrame.scaleY).ceil().clamp(
            rawTop + 1,
            image.height,
          );
          final rawFaceRegion = FrameRegion(
            left: rawLeft,
            top: rawTop,
            width: rawRight - rawLeft,
            height: rawBottom - rawTop,
          );
          final luminance = meanFrameLuminance(
            bytes: plane.bytes,
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            format: LuminanceFormat.bgra8888,
            region: rawFaceRegion,
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
          if (guidance != null) {
            _previousFace = null;
            _trackingId = null;
            _lastValidFaceRegion = null;
            _pendingRgbSamples.clear();
          } else if (experimentalConfig != null) {
            final stabilizedRegion = stabilizeFaceRegion(
              rawFaceRegion,
              previous: _lastValidFaceRegion,
            );
            _lastValidFaceRegion = stabilizedRegion;
            rgbSample = sampleFaceRgbBgra8888(
              bytes: plane.bytes,
              width: image.width,
              height: image.height,
              bytesPerRow: plane.bytesPerRow,
              faceRegion: stabilizedRegion,
            );
            final combined = <TimedFaceRgbSample>[];
            void appendChronological(TimedFaceRgbSample item) {
              if (combined.isEmpty ||
                  item.capturedAt > combined.last.capturedAt) {
                combined.add(item);
              }
            }

            for (final item in priorSamples) {
              if (item.capturedAt < capturedAt) {
                appendChronological(item);
              }
            }
            if (rgbSample != null) {
              appendChronological(
                TimedFaceRgbSample(capturedAt: capturedAt, sample: rgbSample),
              );
            }
            for (final item in _pendingRgbSamples) {
              if (item.capturedAt > capturedAt) {
                appendChronological(item);
              }
            }
            _pendingRgbSamples.clear();
            batchSamples = combined;
          }
        }
      }
      onObservation(
        ScanObservation(
          capturedAt: capturedAt,
          guidance: guidance,
          rgbSample: rgbSample,
          rgbSamples: batchSamples,
        ),
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
    _trackingId = null;
    _lastValidFaceRegion = null;
    _lastDetectionAt = null;
    _pendingRgbSamples.clear();
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
