import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/environment_snapshot.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/db/environment_record_repository.dart';
import 'package:os_2604/services/device/environment_save_service.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';
import 'package:os_2604/widgets/environment_view.dart';

import '../support/fake_environment_transport.dart';
import '../support/environment_packet.dart';
import '../support/fake_scan.dart';

class _Health extends HealthRecordRepository {
  _Health(super.database);
  bool fail = false;
  int inserts = 0;
  Completer<void>? gate;
  @override
  Future<void> insert(HealthCheckResult result) async {
    inserts++;
    await gate?.future;
    if (fail) throw StateError('synthetic failure');
    await super.insert(result);
  }
}

class _Environment implements EnvironmentRecordStore {
  _Environment(this.delegate);
  final EnvironmentRecordStore delegate;
  Completer<void>? gate;
  bool fail = false;
  final writes = <EnvironmentSnapshot>[];
  @override
  Future<bool> attach(String id, EnvironmentSnapshot snapshot) async {
    writes.add(snapshot);
    await gate?.future;
    if (fail) throw StateError('synthetic environment failure');
    return delegate.attach(id, snapshot);
  }

  @override
  Stream<EnvironmentSnapshot?> watch(String id) => delegate.watch(id);
}

void main() {
  late AppDatabase db;
  late _Health health;
  late _Environment environment;
  late FakeScanService scan;
  late FakeEnvironmentTransport transport;
  late LedNotificationService led;
  late EnvironmentSaveService saves;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    health = _Health(db);
    environment = _Environment(EnvironmentRecordRepository(db));
    saves = EnvironmentSaveService(environment);
    scan = FakeScanService();
    transport = FakeEnvironmentTransport();
    led = LedNotificationService(transport, monotonicNow: () => Duration.zero);
  });
  tearDown(() async {
    led.dispose();
    saves.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          repository: health,
          createSession: () => sessionOf(scan),
          ledService: led,
          environmentSaves: saves,
        ),
        routes: {
          AppRoutes.result: (_) => Scaffold(
            body: SavedEnvironmentView(
              recordId: 'rec-1',
              store: environment,
              saves: saves,
            ),
          ),
        },
      ),
    );
    led.initialize();
    transport.status.add(BluetoothAvailability.ready);
    unawaited(led.connect(const LedKit('kit', 'Find Me Target')));
    await tester.pump();
    transport.links.last.add(KitLink.connected);
    await tester.pump();
    led.enableEnvironment(true);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(led.snapshotEnvironment().state, EnvironmentState.available);
    await tester.tap(find.text('開始'));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    led.enableEnvironment(false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'freeze before parent save; navigation retains association, retry writes same snapshot without health insert',
    (tester) async {
      await open(tester);
      health.gate = Completer<void>();
      environment.gate = Completer<void>();
      environment.fail = true;
      scan.finish(successOutcome());
      await tester.pump();
      expect(environment.writes, isEmpty);
      transport.packet = environmentPacket(temperature: 99000);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(led.snapshotEnvironment().ambientTemperatureC, 99);
      health.gate!.complete();
      await tester.pumpAndSettle();
      expect(environment.writes.single.ambientTemperatureC, 23.456);
      expect(find.text('チェックは保存済みです。環境情報を保存しています…'), findsOneWidget);
      environment.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('チェックは保存済みです。環境情報を保存できませんでした'), findsOneWidget);
      environment.fail = false;
      await tester.tap(find.text('環境情報の保存を再試行'));
      await tester.pumpAndSettle();
      expect(health.inserts, 1);
      expect(
        identical(environment.writes.first, environment.writes.last),
        isTrue,
      );
      expect(find.text('キット付近の室温：23.5 ℃'), findsOneWidget);
      expect(find.text('取得元：E84キットのSHT40'), findsOneWidget);
      await led.disconnect();
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('キット付近の室温：23.5 ℃'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets(
    'parent failure writes no environment; parent retry retains completion sample',
    (tester) async {
      await open(tester);
      health.fail = true;
      scan.finish(successOutcome());
      await tester.pumpAndSettle();
      expect(environment.writes, isEmpty);
      transport.packet = environmentPacket(temperature: -1000);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      health.fail = false;
      await tester.tap(find.text('保存を再試行'));
      await tester.pumpAndSettle();
      expect(environment.writes.single.ambientTemperatureC, 23.456);
      expect(await health.loadAll(), hasLength(1));
      await close(tester);
    },
  );
  for (final reason in [
    ScanFailureReason.poorQuality,
    ScanFailureReason.interrupted,
  ]) {
    testWidgets('$reason saves no health or environment record', (
      tester,
    ) async {
      await open(tester);
      scan.finish(
        ScanFailure(reason: reason, elapsed: const Duration(seconds: 4)),
      );
      await tester.pumpAndSettle();
      expect(health.inserts, 0);
      expect(environment.writes, isEmpty);
      await close(tester);
    });
  }
}
