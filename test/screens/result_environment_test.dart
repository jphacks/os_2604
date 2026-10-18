import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/environment_snapshot.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/result_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/environment_record_repository.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/device/environment_save_service.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';
import 'package:os_2604/services/settings/scan_mode_store.dart';

import '../support/fake_led_transport.dart';
import '../support/fake_scan.dart';

class _Mode implements ScanModeStore {
  _Mode(this.research);
  final bool research;
  @override
  Future<bool> loadResearchMode() async => research;
  @override
  Future<void> saveResearchMode(bool enabled) async {}
}

/// attach を止めたり失敗させたりできる保存先。
class _GatedStore extends EnvironmentRecordRepository {
  _GatedStore(super.database);
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<bool> attach(String recordId, EnvironmentSnapshot snapshot) async {
    await gate?.future;
    if (fail) throw StateError('attach failed');
    return super.attach(recordId, snapshot);
  }
}

EnvironmentSnapshot _available() => EnvironmentSnapshot(
  state: EnvironmentState.available,
  ambientTemperatureC: 24.34,
  relativeHumidityPct: 48.4,
  receivedAt: DateTime.utc(2026, 10, 17),
  sampleAgeAtSnapshot: const Duration(seconds: 1),
  sampleSequence: 1,
  protocolVersion: 1,
);

void main() {
  late AppDatabase db;
  late HealthRecordRepository repo;
  late _GatedStore envStore;
  late EnvironmentSaveService saves;
  late FakeLedTransport transport;
  late LedNotificationService led;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
    envStore = _GatedStore(db);
    saves = EnvironmentSaveService(envStore);
    transport = FakeLedTransport();
    led = LedNotificationService(transport);
    await repo.insert(successOutcome().result);
    await repo.updateReport('rec-1', 'レポート', ReportMode.template);
  });
  tearDown(() async {
    led.dispose();
    saves.dispose();
    await db.close();
  });

  Future<void> connectKit(WidgetTester tester) async {
    led.initialize();
    transport.status.add(BluetoothAvailability.ready);
    unawaited(led.connect(const LedKit('kit', 'Find Me Target')));
    await tester.pump();
    transport.links.last.add(KitLink.connected);
    await tester.pump();
    expect(led.ready, isTrue);
  }

  Future<void> open(
    WidgetTester tester, {
    bool research = true,
    bool connected = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (connected) await connectKit(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          repository: repo,
          aiRunner: runnerOf(FakeAiClient()),
          recordId: 'rec-1',
          onBackToHome: () {},
          ledService: led,
          environmentSaves: saves,
          scanModeStore: _Mode(research),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('research ON + kit connected: saved values are shown', (
    tester,
  ) async {
    saves.savedHealthRecord('rec-1', _available());
    await open(tester);
    expect(find.text('室温'), findsOneWidget);
    expect(find.text('24.3℃'), findsOneWidget);
    expect(find.text('相対湿度'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    expect(find.text('キット（研究モード）'), findsNWidgets(2));
    expect(find.text('取得中'), findsNothing);
    await unmount(tester);
  });

  testWidgets('research OFF: rows are hidden', (tester) async {
    saves.savedHealthRecord('rec-1', _available());
    await open(tester, research: false);
    expect(find.text('室温'), findsNothing);
    expect(find.text('相対湿度'), findsNothing);
    expect(find.text('24.3℃'), findsNothing);
    await unmount(tester);
  });

  testWidgets('kit not connected: rows are hidden', (tester) async {
    saves.savedHealthRecord('rec-1', _available());
    await open(tester, connected: false);
    expect(find.text('室温'), findsNothing);
    expect(find.text('相対湿度'), findsNothing);
    await unmount(tester);
  });

  testWidgets('save pending shows 取得中, then the values', (tester) async {
    envStore.gate = Completer<void>();
    saves.savedHealthRecord('rec-1', _available());
    await open(tester);
    expect(find.text('室温'), findsOneWidget);
    expect(find.text('取得中'), findsNWidgets(2));
    expect(find.text('未測定'), findsNothing);
    envStore.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('取得中'), findsNothing);
    expect(find.text('24.3℃'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('non-available snapshot shows 未測定 with the reason', (
    tester,
  ) async {
    saves.savedHealthRecord(
      'rec-1',
      EnvironmentSnapshot(state: EnvironmentState.sensorError),
    );
    await open(tester);
    expect(find.text('未測定'), findsNWidgets(2));
    expect(find.text('センサーから取得できませんでした'), findsNWidgets(2));
    expect(find.text('取得中'), findsNothing);
    await unmount(tester);
  });

  testWidgets('failed save shows 未測定 and keeps the retry UI', (tester) async {
    envStore.fail = true;
    saves.savedHealthRecord('rec-1', _available());
    await open(tester);
    expect(saves.stateFor('rec-1'), EnvironmentSaveState.failed);
    expect(find.text('未測定'), findsNWidgets(2));
    expect(find.text('24.3℃'), findsNothing);
    expect(find.text('チェックは保存済みです。環境情報を保存できませんでした'), findsOneWidget);
    expect(find.text('環境情報の保存を再試行'), findsOneWidget);
    // 再試行で成功すれば値に変わる。
    envStore.fail = false;
    await tester.tap(find.text('環境情報の保存を再試行'));
    await tester.pumpAndSettle();
    expect(find.text('24.3℃'), findsOneWidget);
    expect(find.text('環境情報の保存を再試行'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no environment was saved for this record: 未測定', (tester) async {
    await open(tester);
    expect(find.text('未測定'), findsNWidgets(2));
    expect(find.text('24.3℃'), findsNothing);
    await unmount(tester);
  });
}
