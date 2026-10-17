import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/db/health_record_store.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

class _Onboarding implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

class _Scan implements HealthScanService {
  int starts = 0;
  final response = Completer<ScanOutcome>();
  @override
  ScanProgress get currentProgress => const ScanProgress(phase: ScanPhase.idle);
  @override
  Stream<ScanProgress> get progress => const Stream.empty();
  @override
  Future<ScanOutcome> startHealthScan() {
    starts++;
    return response.future;
  }

  @override
  Future<void> cancelScan() async {
    if (!response.isCompleted) {
      response.complete(
        const ScanFailure(
          reason: ScanFailureReason.interrupted,
          elapsed: Duration.zero,
        ),
      );
    }
  }

  @override
  Future<void> dispose() => cancelScan();
}

class _RetryStore implements HealthRecordStore {
  _RetryStore(this.delegate);
  final HealthRecordStore delegate;
  bool failNextInsert = true;
  @override
  Future<void> insert(HealthCheckResult result) async {
    if (failNextInsert) {
      failNextInsert = false;
      throw StateError('synthetic failure');
    }
    await delegate.insert(result);
  }

  @override
  Future<bool> updateInputsAndReport(HealthCheckResult result) =>
      delegate.updateInputsAndReport(result);
  @override
  Future<List<HealthCheckResult>> loadAll() => delegate.loadAll();
  @override
  Stream<List<HealthCheckResult>> watchAll() => delegate.watchAll();
  @override
  Future<void> deleteOne(String id) => delegate.deleteOne(id);
  @override
  Future<void> deleteAll() => delegate.deleteAll();
}

HealthCheckResult _result() => HealthCheckResult(
  id: 'synthetic-scan',
  measuredAt: DateTime.utc(2026, 10, 17, 1),
  elapsed: const Duration(seconds: 15),
  faceDetected: true,
  quality: MeasurementQuality.good,
);

class _MemoryStore implements HealthRecordStore {
  final _rows = <String, HealthCheckResult>{};
  final _changes = StreamController<List<HealthCheckResult>>.broadcast(
    sync: true,
  );
  @override
  Future<void> insert(HealthCheckResult result) async {
    if (_rows.containsKey(result.id)) throw StateError('Duplicate ID');
    _rows[result.id] = result;
    _changes.add(_rows.values.toList());
  }

  @override
  Future<bool> updateInputsAndReport(HealthCheckResult result) async {
    if (!_rows.containsKey(result.id)) return false;
    _rows[result.id] = result;
    _changes.add(_rows.values.toList());
    return true;
  }

  @override
  Future<List<HealthCheckResult>> loadAll() async => _rows.values.toList();
  @override
  Stream<List<HealthCheckResult>> watchAll() async* {
    yield _rows.values.toList();
    yield* _changes.stream;
  }

  @override
  Future<void> deleteOne(String id) async {
    _rows.remove(id);
    _changes.add(_rows.values.toList());
  }

  @override
  Future<void> deleteAll() async {
    _rows.clear();
    _changes.add([]);
  }
}

void main() {
  late _MemoryStore records;
  late _Scan scan;
  setUp(() {
    records = _MemoryStore();
    scan = _Scan();
  });
  tearDown(() => records._changes.close());

  Future<void> start(WidgetTester tester, {HealthRecordStore? store}) async {
    scan = _Scan();
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Onboarding(),
        recordStore: store ?? records,
        scanServiceFactory: () => scan,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
    final button = find.text('計測開始 / 再試行');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(scan.starts, 1);
  }

  testWidgets(
    'measurement commits before result/report, then inputs, history and deletion use same ID',
    (tester) async {
      await start(tester);
      expect(await records.loadAll(), isEmpty);
      scan.response.complete(ScanSuccess(_result()));
      await tester.pumpAndSettle();
      expect(find.text('計測結果は端末に保存済みです。'), findsOneWidget);
      final first = (await records.loadAll()).single;
      expect(first.id, _result().id);
      expect(first.selfCondition, isNull);
      expect(first.reportText, isNull);
      await tester.tap(find.widgetWithText(ChoiceChip, '4'));
      final save = find.text('任意入力とレポートを保存');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final updated = (await records.loadAll()).single;
      expect(updated.id, first.id);
      expect(updated.selfCondition, 4);
      expect(updated.aiMode, ReportMode.template);
      expect(updated.bodyTemperatureC, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('履歴'));
      await tester.pumpAndSettle();
      expect(find.textContaining('体調：4 / 5'), findsOneWidget);
      await tester.tap(find.byTooltip('この記録を削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      expect(await records.loadAll(), isEmpty);
      expect(find.text('測定記録はまだありません。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed scan never creates a record', (tester) async {
    await start(tester);
    scan.response.complete(
      const ScanFailure(
        reason: ScanFailureReason.faceNotFound,
        elapsed: Duration(seconds: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('顔が見つかりません'), findsOneWidget);
    expect(await records.loadAll(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed insert keeps result for retry and does not show saved screen',
    (tester) async {
      await start(tester, store: _RetryStore(records));
      scan.response.complete(ScanSuccess(_result()));
      await tester.pumpAndSettle();
      expect(find.text('計測結果は端末に保存済みです。'), findsNothing);
      expect(await records.loadAll(), isEmpty);
      final retry = find.text('保存を再試行');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect((await records.loadAll()).single.id, _result().id);
      expect(find.text('計測結果は端末に保存済みです。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
