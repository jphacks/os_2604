import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'package:os_2604/features/scan/experimental_face_signals.dart';
import 'package:os_2604/features/scan/health_scan_controller.dart';
import 'package:os_2604/features/scan/scan_configuration.dart';
import 'package:os_2604/features/scan/scan_frame_source.dart';
import 'package:os_2604/features/scan/scan_permission_gate.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';

class FakeFrames implements ScanFrameSource {
  late void Function(ScanObservation) observation;
  late void Function(ScanFailureReason) failure;
  late Duration Function() now;
  Completer<void>? initializeGate;
  Completer<void>? stopGate;
  bool failStart = false;
  bool failStop = false;
  int stops = 0;
  int disposals = 0;
  int starts = 0;

  @override
  Future<void> start({
    required Duration Function() monotonicNow,
    required void Function(ScanObservation) onObservation,
    required void Function(ScanFailureReason) onFailure,
  }) async {
    starts++;
    now = monotonicNow;
    observation = onObservation;
    failure = onFailure;
    if (failStart) throw StateError('Initialization failed');
    await initializeGate?.future;
  }

  void emit({
    ScanGuidance? issue,
    Duration? capturedAt,
    FaceRgbSample? rgbSample,
    List<TimedFaceRgbSample> rgbSamples = const [],
  }) => observation(
    ScanObservation(
      capturedAt: capturedAt ?? now(),
      guidance: issue,
      rgbSample: rgbSample,
      rgbSamples: rgbSamples,
    ),
  );

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
    if (failStop) throw StateError('Release failed');
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class FakePermissionGate implements ScanPermissionGate {
  Completer<bool> pending = Completer<bool>();

  @override
  Future<bool> request() => pending.future;

  @override
  void cancel() {
    if (!pending.isCompleted) pending.complete(false);
  }
}

void withScan(
  void Function(FakeAsync, FakeFrames, HealthScanController) body, {
  ScanConfiguration? configuration,
}) {
  fakeAsync((time) {
    final frames = FakeFrames();
    final scan = HealthScanController(
      source: frames,
      configuration: configuration ?? ScanConfiguration.day1Trial(),
      monotonicNow: () => time.elapsed,
      wallNow: () => DateTime.utc(2026, 10, 17).add(time.elapsed),
      createId: () => 'synthetic-scan',
    );
    body(time, frames, scan);
    unawaited(scan.dispose());
    time.flushMicrotasks();
  });
}

void goodFrames(FakeAsync time, FakeFrames frames, int milliseconds) {
  for (var i = 0; i < milliseconds ~/ 100; i++) {
    time.elapse(const Duration(milliseconds: 100));
    frames.emit();
    time.flushMicrotasks();
  }
}

void prepare(FakeAsync time, FakeFrames frames) {
  time.flushMicrotasks();
  frames.emit();
  goodFrames(time, frames, 500);
}

void main() {
  test(
    'delayed valid frames never roll progress backwards after a timer tick',
    () {
      withScan((time, frames, scan) {
        scan.startHealthScan();
        prepare(time, frames);
        goodFrames(time, frames, 900);
        time.elapse(const Duration(milliseconds: 100));
        final before = scan.currentProgress.elapsed;
        expect(before, const Duration(seconds: 1));
        frames.emit(
          capturedAt: time.elapsed - const Duration(milliseconds: 50),
        );
        expect(scan.currentProgress.elapsed, before);
        goodFrames(time, frames, 200);
        expect(scan.currentProgress.elapsed, greaterThan(before));
        scan.cancelScan();
        time.flushMicrotasks();
        scan.startHealthScan();
        prepare(time, frames);
        expect(scan.currentProgress.elapsed, Duration.zero);
      });
    },
  );

  test('permission wait is excluded from startup timeout and 15 seconds', () {
    fakeAsync((time) {
      final frames = FakeFrames();
      final permission = FakePermissionGate();
      final scan = HealthScanController(
        source: frames,
        configuration: ScanConfiguration.day1Trial(),
        permissionGate: permission,
        monotonicNow: () => time.elapsed,
        wallNow: () => DateTime.utc(2026, 10, 17).add(time.elapsed),
      );
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 30));
      expect(scan.currentProgress.phase, ScanPhase.requestingPermission);
      expect(scan.currentProgress.elapsed, Duration.zero);
      expect(frames.starts, 0);
      expect(outcome, isNull);
      permission.pending.complete(true);
      prepare(time, frames);
      goodFrames(time, frames, 15000);
      final result = (outcome as ScanSuccess).result;
      expect(result.elapsed, const Duration(seconds: 15));
      expect(result.measuredAt, DateTime.utc(2026, 10, 17, 0, 0, 30, 500));
      unawaited(scan.dispose());
      time.flushMicrotasks();
    });
  });

  test(
    'permission denial and permission errors have distinct failure reasons',
    () {
      for (final denied in [true, false]) {
        fakeAsync((time) {
          final frames = FakeFrames();
          final permission = FakePermissionGate();
          final scan = HealthScanController(
            source: frames,
            configuration: ScanConfiguration.day1Trial(),
            permissionGate: permission,
          );
          ScanOutcome? outcome;
          scan.startHealthScan().then((value) => outcome = value);
          time.flushMicrotasks();
          if (denied) {
            permission.pending.complete(false);
          } else {
            permission.pending.completeError(
              StateError('Synthetic bridge failure'),
            );
          }
          time.flushMicrotasks();
          expect(
            (outcome as ScanFailure).reason,
            denied
                ? ScanFailureReason.permissionDenied
                : ScanFailureReason.cameraUnavailable,
          );
          expect((outcome as ScanFailure).elapsed, Duration.zero);
          expect(frames.starts, 0);
          unawaited(scan.dispose());
          time.flushMicrotasks();
        });
      }
    },
  );

  test(
    'cancel during permission wait finishes immediately and retry works',
    () {
      fakeAsync((time) {
        final frames = FakeFrames();
        final permission = FakePermissionGate();
        final scan = HealthScanController(
          source: frames,
          configuration: ScanConfiguration.day1Trial(),
          permissionGate: permission,
          monotonicNow: () => time.elapsed,
        );
        ScanOutcome? first;
        scan.startHealthScan().then((value) => first = value);
        time.flushMicrotasks();
        unawaited(scan.cancelScan());
        time.flushMicrotasks();
        expect((first as ScanFailure).reason, ScanFailureReason.interrupted);
        expect(frames.starts, 0);
        permission.pending = Completer<bool>()..complete(true);
        ScanOutcome? second;
        scan.startHealthScan().then((value) => second = value);
        prepare(time, frames);
        goodFrames(time, frames, 15000);
        expect(second, isA<ScanSuccess>());
        unawaited(scan.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test('preparation is excluded; success requires 15 seconds and release', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      frames.emit(issue: ScanGuidance.faceNotFound);
      time.elapse(const Duration(seconds: 3));
      expect(scan.currentProgress.phase, ScanPhase.preparing);
      expect(scan.currentProgress.elapsed, Duration.zero);
      frames.emit();
      goodFrames(time, frames, 500);
      expect(scan.currentProgress.phase, ScanPhase.measuring);
      expect(scan.currentProgress.elapsed, Duration.zero);
      goodFrames(time, frames, 14900);
      expect(outcome, isNull);
      goodFrames(time, frames, 100);
      final result = (outcome as ScanSuccess).result;
      expect(result.elapsed, const Duration(seconds: 15));
      expect(result.measuredAt, DateTime.utc(2026, 10, 17, 0, 0, 3, 500));
      expect(result.estimatedHeartRateBpm, isNull);
      expect(result.faceColorFeature, isNull);
      expect(result.bodyTemperatureC, isNull);
      expect(result.reportText, isNull);
      expect(result.aiMode, isNull);
      expect(frames.stops, 1);
    });
  });

  test(
    'clock reaching 15 seconds cannot complete without a terminal frame',
    () {
      withScan((time, frames, scan) {
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        prepare(time, frames);
        goodFrames(time, frames, 14900);
        time.elapse(const Duration(milliseconds: 100));
        expect(scan.currentProgress.remaining, Duration.zero);
        expect(outcome, isNull);
        time.elapse(const Duration(milliseconds: 400));
        time.flushMicrotasks();
        expect((outcome as ScanFailure).reason, ScanFailureReason.poorQuality);
      });
    },
  );

  test('loss of face during measurement never yields a record', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      prepare(time, frames);
      time.elapse(const Duration(milliseconds: 100));
      frames.emit(issue: ScanGuidance.faceNotFound);
      time.flushMicrotasks();
      expect((outcome as ScanFailure).reason, ScanFailureReason.faceNotFound);
      expect(
        (outcome as ScanFailure).elapsed,
        const Duration(milliseconds: 100),
      );
      expect(scan.currentProgress.phase, ScanPhase.failed);
    });
  });

  for (final issue in [
    ScanGuidance.lowLight,
    ScanGuidance.offAngle,
    ScanGuidance.multipleFaces,
    ScanGuidance.missingData,
    ScanGuidance.moving,
  ]) {
    test('$issue invalidates measurement', () {
      withScan((time, frames, scan) {
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        prepare(time, frames);
        time.elapse(const Duration(milliseconds: 100));
        frames.emit(issue: issue);
        time.flushMicrotasks();
        expect((outcome as ScanFailure).reason, ScanFailureReason.poorQuality);
        expect(scan.currentProgress.guidance, issue);
      });
    });
  }

  test('an unstable preparation restarts the full stability interval', () {
    withScan((time, frames, scan) {
      unawaited(scan.startHealthScan());
      time.flushMicrotasks();
      frames.emit();
      goodFrames(time, frames, 400);
      time.elapse(const Duration(milliseconds: 100));
      frames.emit(issue: ScanGuidance.lowLight);
      time.elapse(const Duration(milliseconds: 100));
      frames.emit();
      goodFrames(time, frames, 400);
      expect(scan.currentProgress.phase, ScanPhase.preparing);
      goodFrames(time, frames, 100);
      expect(scan.currentProgress.phase, ScanPhase.measuring);
    });
  });

  test('a preparation gap cannot count as stability', () {
    withScan((time, frames, scan) {
      unawaited(scan.startHealthScan());
      time.flushMicrotasks();
      frames.emit();
      time.elapse(const Duration(seconds: 1));
      frames.emit();
      expect(scan.currentProgress.phase, ScanPhase.preparing);
      goodFrames(time, frames, 500);
      expect(scan.currentProgress.phase, ScanPhase.measuring);
    });
  });

  test('late inference cannot become a successful observation', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      prepare(time, frames);
      goodFrames(time, frames, 14900);
      final old = time.elapsed;
      time.elapse(const Duration(milliseconds: 600));
      frames.emit(capturedAt: old);
      time.flushMicrotasks();
      expect((outcome as ScanFailure).reason, ScanFailureReason.poorQuality);
    });
  });

  test('permission denial is distinct from camera and detection failures', () {
    for (final reason in [
      ScanFailureReason.permissionDenied,
      ScanFailureReason.cameraUnavailable,
      ScanFailureReason.processingFailed,
    ]) {
      withScan((time, frames, scan) {
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        time.flushMicrotasks();
        frames.failure(reason);
        time.flushMicrotasks();
        expect((outcome as ScanFailure).reason, reason);
      });
    }
  });

  test('cancel invalidates old callbacks before a retry', () {
    withScan((time, frames, scan) {
      ScanOutcome? first;
      scan.startHealthScan().then((value) => first = value);
      prepare(time, frames);
      final oldCallback = frames.observation;
      unawaited(scan.cancelScan());
      time.flushMicrotasks();
      expect((first as ScanFailure).reason, ScanFailureReason.interrupted);
      ScanOutcome? second;
      scan.startHealthScan().then((value) => second = value);
      prepare(time, frames);
      oldCallback(
        ScanObservation(
          capturedAt: time.elapsed,
          guidance: ScanGuidance.faceNotFound,
        ),
      );
      expect(second, isNull);
      expect(scan.currentProgress.phase, ScanPhase.measuring);
      goodFrames(time, frames, 15000);
      expect(second, isA<ScanSuccess>());
    });
  });

  test(
    'cancel during camera initialization cleans up after initialization',
    () {
      withScan((time, frames, scan) {
        frames.initializeGate = Completer<void>();
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        time.flushMicrotasks();
        unawaited(scan.cancelScan());
        expect(outcome, isNull);
        frames.initializeGate?.complete();
        time.flushMicrotasks();
        expect((outcome as ScanFailure).reason, ScanFailureReason.interrupted);
        expect(frames.stops, 1);
      });
    },
  );

  test('source initialization exceptions and timeouts become failures', () {
    withScan((time, frames, scan) {
      frames.failStart = true;
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      expect(
        (outcome as ScanFailure).reason,
        ScanFailureReason.cameraUnavailable,
      );
    });
    withScan((time, frames, scan) {
      frames.initializeGate = Completer<void>();
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 10));
      time.flushMicrotasks();
      expect(
        (outcome as ScanFailure).reason,
        ScanFailureReason.cameraUnavailable,
      );
      frames.initializeGate?.complete();
      time.flushMicrotasks();
    });
  });

  test(
    'success is returned only after stop; concurrent starts are rejected',
    () {
      withScan((time, frames, scan) {
        frames.stopGate = Completer<void>();
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        prepare(time, frames);
        goodFrames(time, frames, 15000);
        expect(outcome, isNull);
        var rejected = false;
        scan.startHealthScan().then<void>(
          (_) => fail('Concurrent start accepted'),
          onError: (Object error) {
            rejected = error is StateError;
          },
        );
        time.flushMicrotasks();
        expect(rejected, isTrue);
        frames.stopGate?.complete();
        time.flushMicrotasks();
        expect(outcome, isA<ScanSuccess>());
      });
    },
  );

  test('cleanup errors are never reported as scan success', () {
    withScan((time, frames, scan) {
      frames.failStop = true;
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      prepare(time, frames);
      goodFrames(time, frames, 15000);
      expect(
        (outcome as ScanFailure).reason,
        ScanFailureReason.processingFailed,
      );
    });
  });

  test('immediate cancellation does not open the camera', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      unawaited(scan.cancelScan());
      time.flushMicrotasks();
      expect((outcome as ScanFailure).reason, ScanFailureReason.interrupted);
      expect(frames.starts, 0);
    });
  });

  test('cleanup failure requires a new service before retrying', () {
    withScan((time, frames, scan) {
      frames.failStop = true;
      unawaited(scan.startHealthScan());
      prepare(time, frames);
      unawaited(scan.cancelScan());
      time.flushMicrotasks();
      ScanOutcome? retry;
      scan.startHealthScan().then((value) => retry = value);
      time.flushMicrotasks();
      expect((retry as ScanFailure).reason, ScanFailureReason.processingFailed);
      expect(frames.starts, 1);
    });
  });

  test('invalid timestamps fail; duplicate frames cannot advance time', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      prepare(time, frames);
      frames.emit(capturedAt: Duration.zero);
      expect(scan.currentProgress.elapsed, Duration.zero);
      frames.emit(capturedAt: time.elapsed + const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(
        (outcome as ScanFailure).reason,
        ScanFailureReason.processingFailed,
      );
    });
  });

  test('dispose interrupts scanning and disallows future starts', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      prepare(time, frames);
      unawaited(scan.dispose());
      time.flushMicrotasks();
      expect((outcome as ScanFailure).reason, ScanFailureReason.interrupted);
      expect(frames.disposals, 1);
      var rejected = false;
      scan.startHealthScan().then<void>(
        (_) => fail('Disposed start accepted'),
        onError: (Object error) {
          rejected = error is StateError;
        },
      );
      time.flushMicrotasks();
      expect(rejected, isTrue);
    });
  });

  test(
    'default P0/P1 configuration ignores RGB samples and keeps P2 fields null',
    () {
      withScan((time, frames, scan) {
        ScanOutcome? outcome;
        scan.startHealthScan().then((value) => outcome = value);
        time.flushMicrotasks();
        const sample = FaceRgbSample(red: 180, green: 130, blue: 90);
        frames.emit(rgbSample: sample);
        for (var i = 0; i < 155; i++) {
          time.elapse(const Duration(milliseconds: 100));
          frames.emit(rgbSample: sample);
          time.flushMicrotasks();
        }
        final result = (outcome as ScanSuccess).result;
        expect(result.estimatedHeartRateBpm, isNull);
        expect(result.heartRateSource, HeartRateSource.none);
        expect(result.faceColorFeature, isNull);
        expect(scan.lastExperimentalEvaluation, isNull);
        expect(result.scanMode, ScanMode.standard);
      });
    },
  );

  test('experimental P2 mode records decoupled 30fps RGB batches across 5Hz face detections', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      const prepSample = FaceRgbSample(red: 250, green: 20, blue: 20);
      frames.emit(rgbSample: prepSample);
      for (var i = 0; i < 2; i++) {
        time.elapse(const Duration(milliseconds: 250));
        frames.emit(rgbSample: prepSample);
        time.flushMicrotasks();
      }
      // Now at t=500ms, measuring starts. Emit 75 face-detection observations
      // every 200ms (5Hz), each carrying 6 RGB samples at 30fps (every ~33.3ms).
      final measureStart = time.elapsed;
      for (var cycle = 1; cycle <= 75; cycle++) {
        final batch = <TimedFaceRgbSample>[];
        for (var sub = 5; sub >= 0; sub--) {
          final sampleIndex = cycle * 6 - sub;
          final sampleTime =
              measureStart +
              Duration(microseconds: (sampleIndex * 1000000 / 30.0).round());
          final tSec =
              (sampleTime - measureStart).inMicroseconds /
              Duration.microsecondsPerSecond;
          final pulse = sin(2.0 * pi * (72.0 / 60.0) * tSec);
          batch.add(
            TimedFaceRgbSample(
              capturedAt: sampleTime,
              sample: FaceRgbSample(
                red: 180.0 + 0.25 * pulse,
                green: 120.0 + 1.4 * pulse,
                blue: 100.0 + 0.45 * pulse,
              ),
            ),
          );
        }
        time.elapse(const Duration(milliseconds: 200));
        frames.emit(
          capturedAt: time.elapsed,
          rgbSample: batch.last.sample,
          rgbSamples: batch,
        );
        time.flushMicrotasks();
      }
      final result = (outcome as ScanSuccess).result;
      expect(result.quality, MeasurementQuality.good);
      expect(result.scanMode, ScanMode.research);
      expect(result.faceColorFeature, closeTo(0.45, 0.01));
      expect(result.estimatedHeartRateBpm, isNotNull);
      expect(result.estimatedHeartRateBpm!, closeTo(72.0, 1.0));
      expect(result.heartRateSource, HeartRateSource.rppgExperimental);
      expect(
        scan.lastExperimentalEvaluation?.shootingConditions?.sampleCount,
        greaterThanOrEqualTo(450),
      );
      expect(
        scan.lastExperimentalEvaluation?.shootingConditions?.effectiveFps,
        closeTo(30.0, 0.5),
      );
    }, configuration: ScanConfiguration.day1Experimental());
  });

  test('poor rPPG signal quality in experimental mode still completes P0 scan with null BPM', () {
    withScan((time, frames, scan) {
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      const flatSample = FaceRgbSample(red: 180, green: 120, blue: 100);
      frames.emit(rgbSample: flatSample);
      for (var i = 0; i < 155; i++) {
        time.elapse(const Duration(milliseconds: 100));
        frames.emit(rgbSample: flatSample);
        time.flushMicrotasks();
      }
      final result = (outcome as ScanSuccess).result;
      expect(result.quality, MeasurementQuality.good);
      expect(result.faceColorFeature, closeTo(0.45, 0.001));
      expect(result.estimatedHeartRateBpm, isNull);
      expect(result.heartRateSource, HeartRateSource.none);
    }, configuration: ScanConfiguration.day1Experimental());
  });

  test('cleanup failure or cancellation in experimental mode clears evaluation state', () {
    withScan((time, frames, scan) {
      frames.failStop = true;
      ScanOutcome? outcome;
      scan.startHealthScan().then((value) => outcome = value);
      time.flushMicrotasks();
      const sample = FaceRgbSample(red: 180, green: 120, blue: 100);
      frames.emit(rgbSample: sample);
      for (var i = 0; i < 155; i++) {
        time.elapse(const Duration(milliseconds: 100));
        frames.emit(rgbSample: sample);
        time.flushMicrotasks();
      }
      expect(
        (outcome as ScanFailure).reason,
        ScanFailureReason.processingFailed,
      );
      expect(scan.lastExperimentalEvaluation, isNull);
    }, configuration: ScanConfiguration.day1Experimental());
  });
}
