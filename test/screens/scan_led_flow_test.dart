import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';

import '../support/fake_led_transport.dart';
import '../support/fake_scan.dart';

class _Repository extends HealthRecordRepository {
  _Repository(super.database);
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<void> insert(HealthCheckResult result) async {
    await gate?.future;
    if (fail) throw StateError('test save failed');
    await super.insert(result);
  }
}

void main() {
  late AppDatabase db;
  late _Repository repository;
  late FakeScanService scan;
  late FakeLedTransport transport;
  late LedNotificationService led;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = _Repository(db);
    scan = FakeScanService();
    transport = FakeLedTransport();
    led = LedNotificationService(transport);
  });

  tearDown(() async {
    led.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester, {bool connected = true}) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScanScreen(
                    repository: repository,
                    createSession: () => sessionOf(scan),
                    ledService: led,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        routes: {
          AppRoutes.result: (_) => const Scaffold(body: Text('saved-result')),
        },
      ),
    );
    led.initialize();
    transport.status.add(BluetoothAvailability.ready);
    if (connected) {
      unawaited(led.connect(const LedKit('kit', 'Find Me Target')));
      await tester.pump();
      transport.links.last.add(KitLink.connected);
      await tester.pump();
      expect(led.ready, isTrue);
      unawaited(led.testLed());
      await tester.pump();
      led.enableAutomatic(true);
      expect(led.automatic, isTrue);
    }
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(scan.starts, 1);
    transport.writes.clear();
  }

  List<int> getLevels() => transport.writes.map((w) => w.$2).toList();

  testWidgets(
    'DB success precedes one pulse; result navigation retains off timer',
    (tester) async {
      await open(tester);
      repository.gate = Completer<void>();
      scan.finish(successOutcome());
      await tester.pump();
      expect(getLevels(), isEmpty);
      expect(await repository.findById('rec-1'), isNull);
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(await repository.findById('rec-1'), isNotNull);
      expect(find.text('saved-result'), findsOneWidget);
      expect(getLevels(), [2]);
      await tester.pump(const Duration(seconds: 3));
      expect(getLevels(), [2, 0]);
      await tester.pump();
      expect(getLevels(), [2, 0]);
    },
  );

  testWidgets('failed save cannot pulse; retry succeeds exactly once', (
    tester,
  ) async {
    await open(tester);
    repository.fail = true;
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(getLevels(), isEmpty);
    repository.fail = false;
    await tester.tap(find.text('保存を再試行'));
    await tester.pumpAndSettle();
    expect(getLevels(), [2]);
    expect(find.text('saved-result'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(getLevels(), [2, 0]);
  });

  for (final reason in [
    ScanFailureReason.faceNotFound,
    ScanFailureReason.poorQuality,
    ScanFailureReason.interrupted,
  ]) {
    testWidgets('$reason never pulses or saves', (tester) async {
      await open(tester);
      scan.finish(ScanFailure(reason: reason, elapsed: Duration.zero));
      await tester.pumpAndSettle();
      expect(getLevels().where((v) => v == 2), isEmpty);
      expect(await repository.loadAll(), isEmpty);
    });
  }

  testWidgets('back racing save never sends a late pulse', (tester) async {
    await open(tester);
    repository.gate = Completer<void>();
    scan.finish(successOutcome());
    await tester.pump();
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(getLevels().where((v) => v == 2), isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'background racing DB save cannot pulse after foreground returns',
    (tester) async {
      await open(tester);
      repository.gate = Completer<void>();
      scan.finish(successOutcome());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(getLevels().where((v) => v == 2), isEmpty);
    },
  );

  testWidgets('BLE timeout does not hold saved result screen', (tester) async {
    await open(tester);
    final gate = Completer<void>();
    transport.writeGate = gate;
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(find.text('saved-result'), findsOneWidget);
    expect(await repository.findById('rec-1'), isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(led.delivery, LedDelivery.failed);
    gate.complete();
    await tester.pump();
    expect(getLevels(), [2]);
  });

  testWidgets(
    'first camera permission inactive does not discard successful attempt',
    (tester) async {
      await open(tester);
      scan.emit(const ScanProgress(phase: ScanPhase.requestingPermission));
      await tester.pump();
      led.setForeground(false, interrupt: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      led.setForeground(true);
      scan.finish(successOutcome());
      await tester.pumpAndSettle();
      expect(getLevels(), [2]);
      await tester.pump(const Duration(seconds: 3));
      expect(getLevels(), [2, 0]);
    },
  );

  testWidgets('no kit still saves and navigates', (tester) async {
    await open(tester, connected: false);
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(find.text('saved-result'), findsOneWidget);
    expect(await repository.findById('rec-1'), isNotNull);
    expect(getLevels(), isEmpty);
    expect(led.delivery, LedDelivery.skipped);
  });
}
