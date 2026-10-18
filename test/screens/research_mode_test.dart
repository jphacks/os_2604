import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';
import 'package:os_2604/services/settings/scan_mode_store.dart';

import '../support/fake_scan.dart';
import '../support/fake_reminder.dart';

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

class _FailStore implements ScanModeStore {
  @override
  Future<bool> loadResearchMode() async => throw Exception('load');
  @override
  Future<void> saveResearchMode(bool enabled) async => throw Exception('save');
}

class _SaveFailureStore implements ScanModeStore {
  @override
  Future<bool> loadResearchMode() async => false;
  @override
  Future<void> saveResearchMode(bool enabled) async => throw Exception('save');
}

void main() {
  late AppDatabase db;
  late HealthRecordRepository repo;
  late List<FakeScanService> standard;
  late List<FakeScanService> research;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HealthRecordRepository(db);
    standard = [];
    research = [];
  });
  tearDown(() => db.close());
  Future<void> open(WidgetTester tester, {ScanModeStore? store}) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MorningCheckApp(
        onboardingStore: _Done(),
        repository: repo,
        aiRunner: runnerOf(FakeAiClient()),
        reminderService: FakeReminderService(),
        reminderStore: FakeReminderStore(),
        scanModeStore: store ?? DriftScanModeStore(db),
        createScanSession: () {
          final s = FakeScanService();
          standard.add(s);
          return sessionOf(s);
        },
        createResearchScanSession: () {
          final s = FakeScanService();
          research.add(s);
          return sessionOf(s);
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> camera(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('main-tab-1')));
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 1));
  }

  testWidgets('standard is default and starts automatically without research', (
    t,
  ) async {
    await open(t);
    await camera(t);
    expect(standard.single.starts, 1);
    expect(research, isEmpty);
    expect(find.text('通常モード'), findsNothing); // 通常モードは表示しない
    expect(find.text('研究モード（試験機能）'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await close(t);
  });
  testWidgets(
    'settings persists research; camera auto-starts it and saves mode with null estimates',
    (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('main-tab-2')));
      await t.pumpAndSettle();
      expect(
        t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(
        await t.runAsync(() => DriftScanModeStore(db).loadResearchMode()),
        isTrue,
      );
      await camera(t);
      expect(standard, isEmpty);
      expect(research.single.starts, 1);
      expect(find.text('研究モード（試験機能）'), findsOneWidget);
      research.single.finish(
        ScanSuccess(
          HealthCheckResult(
            id: 'research-null',
            measuredAt: DateTime(2026, 10, 18),
            elapsed: const Duration(seconds: 15),
            faceDetected: true,
            quality: MeasurementQuality.good,
            scanMode: ScanMode.research,
          ),
        ),
      );
      await t.pumpAndSettle();
      final saved = (await t.runAsync(() => repo.findById('research-null')))!;
      expect(saved.scanMode, ScanMode.research);
      expect(saved.estimatedHeartRateBpm, isNull);
      expect(saved.faceColorFeature, isNull);
      await close(t);
      // Recreate the application: selection survives and can be turned off.
      await open(t);
      await t.tap(find.byKey(const ValueKey('main-tab-2')));
      await t.pumpAndSettle();
      expect(
        t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      await camera(t);
      expect(standard.single.starts, 1);
      expect(research, hasLength(1));
      await close(t);
    },
  );
  testWidgets('failed setting save keeps standard mode and reports failure', (
    t,
  ) async {
    await open(t, store: _SaveFailureStore());
    await t.tap(find.byKey(const ValueKey('main-tab-2')));
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(
      t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.textContaining('計測モードを保存できませんでした'), findsOneWidget);
    await camera(t);
    expect(standard.single.starts, 1);
    expect(research, isEmpty);
    await close(t);
  });
  testWidgets('preference read failure never starts a camera', (t) async {
    await open(t, store: _FailStore());
    await camera(t);
    expect(find.text('計測モードを読み込めませんでした'), findsOneWidget);
    expect(standard, isEmpty);
    expect(research, isEmpty);
    await close(t);
  });
}
