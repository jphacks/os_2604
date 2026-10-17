import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../models/health_check_result.dart';
import '../../models/scan_contract.dart';
import 'scan_configuration.dart';
import 'scan_frame_source.dart';

/// Owns the only measurement clock. B observes progress and persists success.
class HealthScanController implements HealthScanService {
  HealthScanController({
    required this._source,
    required this._configuration,
    Duration Function()? monotonicNow,
    DateTime Function()? wallNow,
    String Function()? createId,
  }) {
    final stopwatch = Stopwatch()..start();
    _now = monotonicNow ?? () => stopwatch.elapsed;
    _wallNow = wallNow ?? DateTime.now;
    _createId = createId ?? _randomId;
  }

  final ScanFrameSource _source;
  final ScanConfiguration _configuration;
  late final Duration Function() _now;
  late final DateTime Function() _wallNow;
  late final String Function() _createId;
  final _progress = StreamController<ScanProgress>.broadcast();
  ScanProgress _current = const ScanProgress(phase: ScanPhase.idle);
  Completer<ScanOutcome>? _result;
  Future<void>? _launch;
  Future<void>? _finishing;
  Timer? _timer;
  int _generation = 0;
  int? _active;
  bool _disposed = false;
  bool _cleanupFailed = false;
  Future<void>? _disposing;
  Duration? _lastCaptured;
  Duration? _stableSince;
  Duration? _measurementStart;
  DateTime? _measuredAt;

  @override
  ScanProgress get currentProgress => _current;
  @override
  Stream<ScanProgress> get progress => _progress.stream;

  @override
  Future<ScanOutcome> startHealthScan() {
    if (_disposed) return Future.error(StateError('Scan service is disposed.'));
    if (_cleanupFailed) {
      return Future.value(
        const ScanFailure(
          reason: ScanFailureReason.processingFailed,
          elapsed: Duration.zero,
        ),
      );
    }
    final previous = _result;
    if (previous != null && !previous.isCompleted) {
      return Future.error(StateError('A scan is already active or stopping.'));
    }
    final result = Completer<ScanOutcome>();
    _result = result;
    final generation = ++_generation;
    _active = generation;
    _lastCaptured = null;
    _stableSince = null;
    _measurementStart = null;
    _measuredAt = null;
    _finishing = null;
    _emit(const ScanProgress(phase: ScanPhase.preparing));
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    final launch = Future<void>.microtask(() {
      if (_active != generation) return Future<void>.value();
      return _source.start(
        monotonicNow: _now,
        onObservation: (observation) => _observe(generation, observation),
        onFailure: (reason) {
          if (_active == generation) _fail(reason);
        },
      );
    }).timeout(const Duration(seconds: 10));
    _launch = launch;
    unawaited(
      launch.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (_active == generation) _fail(ScanFailureReason.cameraUnavailable);
        },
      ),
    );
    return result.future;
  }

  void _observe(int generation, ScanObservation observation) {
    if (_active != generation) return;
    final now = _now();
    final captured = observation.capturedAt;
    if (captured.isNegative || captured > now) {
      _fail(ScanFailureReason.processingFailed);
      return;
    }
    final previous = _lastCaptured;
    if (previous != null && captured <= previous) return;
    if (now - captured >= _configuration.maxObservationGap ||
        (previous != null &&
            captured - previous >= _configuration.maxObservationGap)) {
      _stableSince = null;
      if (_measurementStart != null) {
        _fail(ScanFailureReason.poorQuality);
        return;
      }
      // A fresh frame after a preparation gap can begin a new stability period.
      if (now - captured >= _configuration.maxObservationGap) {
        _emit(
          const ScanProgress(
            phase: ScanPhase.preparing,
            guidance: ScanGuidance.noFrames,
          ),
        );
        return;
      }
    }
    _lastCaptured = captured;
    final issue = observation.guidance;
    if (issue != null) {
      _stableSince = null;
      if (_measurementStart != null) {
        _fail(
          issue == ScanGuidance.faceNotFound
              ? ScanFailureReason.faceNotFound
              : ScanFailureReason.poorQuality,
        );
      } else {
        _emit(ScanProgress(phase: ScanPhase.preparing, guidance: issue));
      }
      return;
    }
    final started = _measurementStart;
    if (started == null) {
      final stable = _stableSince ??= captured;
      if (captured - stable >= _configuration.preparationStability) {
        _measurementStart = captured;
        _measuredAt = _wallNow().subtract(now - captured);
        _emit(const ScanProgress(phase: ScanPhase.measuring));
      } else {
        _emit(const ScanProgress(phase: ScanPhase.preparing));
      }
      return;
    }
    final elapsed = captured - started;
    if (elapsed >= HealthCheckResult.targetDuration) {
      final measuredAt = _measuredAt;
      if (measuredAt == null) {
        _fail(ScanFailureReason.processingFailed);
        return;
      }
      try {
        final record = HealthCheckResult(
          id: _createId(),
          measuredAt: measuredAt,
          elapsed: elapsed,
          faceDetected: true,
          quality: MeasurementQuality.good,
        );
        unawaited(_finish(ScanSuccess(record)));
      } on Object {
        _fail(ScanFailureReason.processingFailed);
      }
    } else {
      _emit(ScanProgress(phase: ScanPhase.measuring, elapsed: elapsed));
    }
  }

  void _tick() {
    if (_active == null) return;
    final last = _lastCaptured;
    if (last == null || _now() - last >= _configuration.maxObservationGap) {
      _stableSince = null;
      if (_measurementStart != null) {
        _fail(ScanFailureReason.poorQuality);
      } else {
        _emit(
          const ScanProgress(
            phase: ScanPhase.preparing,
            guidance: ScanGuidance.noFrames,
          ),
        );
      }
      return;
    }
    if (_measurementStart != null) {
      // UI updates never complete the scan: a valid terminal frame is required.
      _emit(ScanProgress(phase: ScanPhase.measuring, elapsed: _elapsed()));
    }
  }

  Duration _elapsed() {
    final started = _measurementStart;
    if (started == null) return Duration.zero;
    final value = _now() - started;
    return value.isNegative ? Duration.zero : value;
  }

  void _fail(ScanFailureReason reason) {
    unawaited(_finish(ScanFailure(reason: reason, elapsed: _elapsed())));
  }

  Future<void> _finish(ScanOutcome outcome) {
    if (_active == null) return _finishing ?? Future<void>.value();
    _active = null; // Invalidate callbacks before the first await.
    _timer?.cancel();
    _timer = null;
    final result = _result;
    final elapsed = _elapsed();
    final launch = _launch;
    final finishing = () async {
      try {
        await launch;
      } on Object {
        /* Failure is represented by outcome. */
      }
      var finalOutcome = outcome;
      try {
        await _source.stop().timeout(const Duration(seconds: 10));
      } on Object {
        _cleanupFailed = true;
        // Resource cleanup failure must not be reported as successful scanning.
        finalOutcome = ScanFailure(
          reason: ScanFailureReason.processingFailed,
          elapsed: elapsed,
        );
      }
      switch (finalOutcome) {
        case ScanSuccess(:final result):
          _emit(
            ScanProgress(phase: ScanPhase.completed, elapsed: result.elapsed),
          );
        case ScanFailure(:final reason, :final elapsed):
          _emit(
            ScanProgress(
              phase: ScanPhase.failed,
              elapsed: elapsed,
              failureReason: reason,
            ),
          );
      }
      if (result != null && !result.isCompleted) result.complete(finalOutcome);
    }();
    _finishing = finishing;
    return finishing;
  }

  void _emit(ScanProgress value) {
    _current = value;
    if (!_progress.isClosed) _progress.add(value);
  }

  @override
  Future<void> cancelScan() async {
    if (_active != null) {
      await _finish(
        ScanFailure(reason: ScanFailureReason.interrupted, elapsed: _elapsed()),
      );
    } else {
      await _finishing;
    }
  }

  @override
  Future<void> dispose() {
    final disposing = _disposing;
    if (disposing != null) return disposing;
    _disposed = true;
    final operation = () async {
      await cancelScan();
      try {
        await _source.dispose();
      } finally {
        await _progress.close();
      }
    }();
    _disposing = operation;
    return operation;
  }

  static String _randomId() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}
