import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

class FakeScanService implements HealthScanService {
  final _controller = StreamController<ScanProgress>.broadcast();
  Completer<ScanOutcome> _pending = Completer();
  int starts = 0;
  int cancels = 0;
  int disposes = 0;
  ScanProgress _current = const ScanProgress(phase: ScanPhase.idle);

  @override
  ScanProgress get currentProgress => _current;
  @override
  Stream<ScanProgress> get progress => _controller.stream;

  void emit(ScanProgress p) {
    _current = p;
    _controller.add(p);
  }

  void finish(ScanOutcome o) => _pending.complete(o);

  @override
  Future<ScanOutcome> startHealthScan() {
    starts++;
    _pending = Completer();
    return _pending.future;
  }

  @override
  Future<void> cancelScan() async => cancels++;

  @override
  Future<void> dispose() async => disposes++;
}

ScanSuccess successOutcome([String id = 'rec-1']) => ScanSuccess(
  HealthCheckResult(
    id: id,
    measuredAt: DateTime(2026, 10, 17, 8, 30),
    elapsed: const Duration(seconds: 15, milliseconds: 200),
    faceDetected: true,
    quality: MeasurementQuality.good,
  ),
);

/// Repository whose writes can be made to fail.
class FlakyRepository extends HealthRecordRepository {
  FlakyRepository(super.database);
  bool failInsert = false;
  bool failUpdate = false;

  @override
  Future<void> insert(HealthCheckResult result) async {
    if (failInsert) throw StateError('insert failed');
    return super.insert(result);
  }

  @override
  Future<void> updateSelfCondition(String id, int selfCondition) async {
    if (failUpdate) throw StateError('update failed');
    return super.updateSelfCondition(id, selfCondition);
  }

  @override
  Future<void> updateTemperature(
    String id,
    double celsius,
    TemperatureSource source,
  ) async {
    if (failUpdate) throw StateError('update failed');
    return super.updateTemperature(id, celsius, source);
  }
}

ScanSession sessionOf(FakeScanService s) =>
    (service: s, preview: ValueNotifier(null));
