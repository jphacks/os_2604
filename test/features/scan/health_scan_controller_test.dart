import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import '../../../lib/features/scan/health_scan_controller.dart';
import '../../../lib/features/scan/scan_configuration.dart';
import '../../../lib/features/scan/scan_frame_source.dart';
import '../../../lib/models/scan_contract.dart';

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

  void emit({ScanGuidance? issue, Duration? capturedAt}) => observation(
    ScanObservation(capturedAt: capturedAt ?? now(), guidance: issue),
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

void withScan(void Function(FakeAsync, FakeFrames, HealthScanController) body) {
  fakeAsync((time) {
    final frames = FakeFrames();
    final scan = HealthScanController(
      source: frames,
      configuration: ScanConfiguration.day1Trial(),
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
}
