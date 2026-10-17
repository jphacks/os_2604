import 'dart:async';

import 'package:camera/camera.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/features/scan/health_scan_controller.dart';
import 'package:os_2604/features/scan/scan_configuration.dart';
import 'package:os_2604/features/scan/scan_frame_source.dart';
import 'package:os_2604/features/scan/scan_permission_gate.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

class _Permission implements ScanPermissionGate {
  Completer<bool> pending = Completer<bool>();

  @override
  Future<bool> request() => pending.future;

  @override
  void cancel() {
    if (!pending.isCompleted) pending.complete(false);
  }
}

class _Frames implements ScanFrameSource {
  int starts = 0;
  int disposals = 0;

  @override
  Future<void> start({
    required Duration Function() monotonicNow,
    required void Function(ScanObservation) onObservation,
    required void Function(ScanFailureReason) onFailure,
  }) async => starts++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  late AppDatabase db;
  late HealthRecordRepository repository;
  late _Permission permission;
  late _Frames frames;
  late HealthScanController scan;
  late ValueNotifier<CameraController?> preview;
  late GlobalKey<NavigatorState> navigator;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = HealthRecordRepository(db);
    navigator = GlobalKey<NavigatorState>();
  });

  tearDown(() async {
    preview.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    // Create the service and its futures inside the widget test's clock zone.
    permission = _Permission();
    frames = _Frames();
    scan = HealthScanController(
      source: frames,
      configuration: ScanConfiguration.day1Trial(),
      permissionGate: permission,
    );
    preview = ValueNotifier(null);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
        routes: {
          '/scan': (_) => ScanScreen(
            repository: repository,
            createSession: () => (service: scan, preview: preview),
          ),
        },
      ),
    );
    unawaited(navigator.currentState!.pushNamed('/scan'));
    await tester.pumpAndSettle();
    await tester.pump();
  }

  testWidgets(
    'B screen waits through permission inactivity and can leave safely',
    (tester) async {
      await open(tester);
      expect(find.text('カメラの許可を確認しています'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 30));
      expect(scan.currentProgress.phase, ScanPhase.requestingPermission);
      expect(scan.currentProgress.elapsed, Duration.zero);
      expect(frames.starts, 0);
      expect(find.byType(FilledButton), findsNothing); // 開始ボタンは無い
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('中止する'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(frames.starts, 0);
      expect(frames.disposals, 1);
      expect(await repository.loadAll(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permission denial in B screen is unsaved and can retry after allow',
    (tester) async {
      await open(tester);
      permission.pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('カメラの許可が必要です'), findsOneWidget);
      expect(frames.starts, 0);
      expect(await repository.loadAll(), isEmpty);
      permission.pending = Completer<bool>();
      await tester.tap(find.text('もう一度測る'));
      await tester.pump();
      expect(scan.currentProgress.phase, ScanPhase.requestingPermission);
      permission.pending.complete(true);
      await tester.pump();
      expect(scan.currentProgress.phase, ScanPhase.preparing);
      expect(frames.starts, 1);
      await tester.tap(find.text('中止する'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(frames.disposals, 1);
      expect(await repository.loadAll(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
