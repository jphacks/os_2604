import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:os_2604/features/scan/ios_camera_frame_source.dart';
import 'package:os_2604/features/scan/scan_configuration.dart';
import 'package:os_2604/features/scan/scan_frame_source.dart';
import 'package:os_2604/models/scan_contract.dart';

class FakeCamera extends CameraPlatform {
  final frames = StreamController<CameraImageData>.broadcast();
  // CameraController listens for the first native error for its entire lifetime.
  final errors = StreamController<CameraErrorEvent>.broadcast();
  String? initializationError;
  bool audioEnabled = true;
  int disposals = 0;
  DeviceOrientation? lockedOrientation;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'synthetic-front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? resolution, {
    bool enableAudio = false,
  }) async {
    audioEnabled = enableAudio;
    final error = initializationError;
    if (error != null) throw PlatformException(code: error);
    return 1;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          10,
          10,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {
    lockedOrientation = orientation;
  }

  @override
  bool supportsImageStreaming() => true;
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => frames.stream;
  @override
  Future<void> dispose(int cameraId) async {
    disposals++;
  }

  void emit({int brightness = 100, bool truncated = false}) => frames.add(
    CameraImageData(
      format: const CameraImageFormat(
        ImageFormatGroup.bgra8888,
        raw: 0x42475241,
      ),
      planes: [
        CameraImagePlane(
          bytes: Uint8List.fromList(
            List.filled(truncated ? 1 : 400, brightness),
          ),
          bytesPerRow: 40,
        ),
      ],
      height: 10,
      width: 10,
    ),
  );
}

Map<String, Object?> syntheticFace({double? yaw = 0}) => {
  'rect': {'left': 3.0, 'top': 2.0, 'right': 7.0, 'bottom': 8.0},
  'headEulerAngleX': 0.0,
  'headEulerAngleY': yaw,
  'headEulerAngleZ': 0.0,
  'landmarks': <String, Object?>{},
  'contours': <String, Object?>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_face_detector');
  late FakeCamera camera;
  late CameraPlatform original;
  late IosCameraFrameSource source;
  late List<ScanObservation> observations;
  late List<ScanFailureReason> failures;
  late List<Map<String, Object?>> faces;
  Completer<Object?>? inferenceGate;
  var detectorCloses = 0;

  setUp(() {
    original = CameraPlatform.instance;
    camera = FakeCamera();
    CameraPlatform.instance = camera;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    source = IosCameraFrameSource(ScanConfiguration.day1Trial());
    observations = [];
    failures = [];
    faces = [syntheticFace()];
    inferenceGate = null;
    detectorCloses = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vision#closeFaceDetector') {
            detectorCloses++;
            return null;
          }
          final gate = inferenceGate;
          return gate == null ? faces : await gate.future;
        });
  });

  tearDown(() async {
    await source.dispose();
    await camera.frames.close();
    CameraPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> start() => source.start(
    monotonicNow: () => const Duration(seconds: 1),
    onObservation: observations.add,
    onFailure: failures.add,
  );

  Future<void> flushFrame() async {
    // Let the image stream and mocked method-channel response run.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('front camera uses BGRA without audio and cleans up on stop', () async {
    await start();
    expect(camera.audioEnabled, isFalse);
    expect(camera.lockedOrientation, DeviceOrientation.portraitUp);
    expect(source.preview.value, isNotNull);
    camera.emit();
    await flushFrame();
    expect(observations.single.guidance, isNull);
    expect(observations.single.capturedAt, const Duration(seconds: 1));
    await source.stop();
    expect(source.preview.value, isNull);
    expect(camera.disposals, 1);
    expect(detectorCloses, 1);
  });

  for (final code in [
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  ]) {
    test('$code maps to permissionDenied', () async {
      camera.initializationError = code;
      await start();
      expect(failures, [ScanFailureReason.permissionDenied]);
    });
  }

  test(
    'other camera failures are not mislabeled as permission denial',
    () async {
      camera.initializationError = 'CameraNotFound';
      await start();
      expect(failures, [ScanFailureReason.cameraUnavailable]);
    },
  );

  test('no face, missing angles and low light do not pass quality', () async {
    await start();
    faces = [];
    camera.emit();
    await flushFrame();
    expect(observations.last.guidance, ScanGuidance.faceNotFound);
    faces = [syntheticFace(yaw: null)];
    camera.emit();
    await flushFrame();
    expect(observations.last.guidance, ScanGuidance.missingData);
    faces = [syntheticFace()];
    camera.emit(brightness: 10);
    await flushFrame();
    expect(observations.last.guidance, ScanGuidance.lowLight);
  });

  test('malformed buffers fail before reaching native inference', () async {
    await start();
    camera.emit(truncated: true);
    await flushFrame();
    expect(failures, [ScanFailureReason.processingFailed]);
    expect(observations, isEmpty);
  });

  test('late inference after stop cannot update a retry', () async {
    await start();
    final gate = Completer<Object?>();
    inferenceGate = gate;
    camera.emit();
    await flushFrame();
    expect(observations, isEmpty);
    await source.stop();
    inferenceGate = null;
    await start();
    gate.complete([syntheticFace()]);
    await flushFrame();
    expect(observations, isEmpty);
    camera.emit();
    await flushFrame();
    expect(observations.single.guidance, isNull);
  });

  test(
    'native stream errors become failures without escaping the session',
    () async {
      await start();
      camera.frames.addError(StateError('Synthetic stream failure'));
      await flushFrame();
      expect(failures, [ScanFailureReason.processingFailed]);
    },
  );

  test('experimental configuration samples RGB only when frame quality passes and collects 30fps intermediate frames while throttled', () async {
    await source.dispose();
    var currentTime = const Duration(seconds: 1);
    source = IosCameraFrameSource(ScanConfiguration.day1Experimental());
    var mlkitCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vision#closeFaceDetector') {
            detectorCloses++;
            return null;
          }
          mlkitCalls++;
          final gate = inferenceGate;
          return gate == null ? faces : await gate.future;
        });
    await source.start(
      monotonicNow: () => currentTime,
      onObservation: observations.add,
      onFailure: failures.add,
    );

    // Frame 0 at t=1000ms runs ML Kit and establishes _lastValidFaceRegion.
    camera.emit(brightness: 120);
    await flushFrame();
    expect(mlkitCalls, 1);
    expect(observations.last.guidance, isNull);
    expect(observations.last.rgbSample, isNotNull);
    expect(observations.last.rgbSample!.red, closeTo(120, 0.0001));

    // Intermediate 30fps frames at +33ms, +66ms, +100ms, +133ms (< 180ms interval)
    // sample RGB without invoking ML Kit face detection.
    for (final offsetMs in [33, 66, 100, 133]) {
      currentTime = Duration(milliseconds: 1000 + offsetMs);
      camera.emit(brightness: 120 + offsetMs ~/ 33);
      await flushFrame();
    }
    expect(mlkitCalls, 1);
    expect(observations.length, 1);

    // Next detection frame at +200ms (>= 180ms interval) invokes ML Kit once
    // and flushes all 5 chronological 30fps RGB samples in rgbSamples.
    currentTime = const Duration(milliseconds: 1200);
    camera.emit(brightness: 130);
    await flushFrame();
    expect(mlkitCalls, 2);
    expect(observations.length, 2);
    expect(observations.last.guidance, isNull);
    expect(observations.last.rgbSamples.length, 5);
    expect(observations.last.rgbSamples.map((e) => e.capturedAt).toList(), [
      const Duration(milliseconds: 1033),
      const Duration(milliseconds: 1066),
      const Duration(milliseconds: 1100),
      const Duration(milliseconds: 1133),
      const Duration(milliseconds: 1200),
    ]);

    // Low-light frame clears valid face region and drops RGB samples.
    currentTime = const Duration(milliseconds: 1400);
    camera.emit(brightness: 10);
    await flushFrame();
    expect(observations.last.guidance, ScanGuidance.lowLight);
    expect(observations.last.rgbSample, isNull);
    expect(observations.last.rgbSamples, isEmpty);
  });
}
