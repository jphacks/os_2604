import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';

import '../support/fake_scan.dart';
import '../support/fake_reminder.dart';

class _Done implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;
  @override
  Future<void> completeOnboarding() async {}
}

class _SlowDispose extends FakeScanService {
  final gate = Completer<void>();
  @override
  Future<void> dispose() async {
    await super.dispose();
    await gate.future;
  }
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

  Future<void> open(
    WidgetTester tester, {
    FakeScanService Function()? createStandard,
  }) async {
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
        createScanSession: () {
          final scan = createStandard?.call() ?? FakeScanService();
          standard.add(scan);
          return sessionOf(scan);
        },
        createResearchScanSession: () {
          final scan = FakeScanService();
          research.add(scan);
          return sessionOf(scan);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェック開始'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'research is opt-in, locked during scan and saved even without an estimate',
    (tester) async {
      await open(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(research, isEmpty);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(standard.single.disposes, 1);
      expect(research, hasLength(1));
      await tester.tap(find.text('開始'));
      await tester.pump();
      expect(research.single.starts, 1);
      expect(standard.single.starts, 0);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
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
      await tester.pumpAndSettle();
      expect(find.text('研究モード'), findsOneWidget);
      expect(find.textContaining('研究用の試験機能'), findsOneWidget);
      final saved = (await repo.findById('research-null'))!;
      expect(saved.scanMode, ScanMode.research);
      expect(saved.estimatedHeartRateBpm, isNull);
      await tester.ensureVisible(find.text('4'));
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.ensureVisible(find.text('体調を保存'));
      await tester.tap(find.text('体調を保存'));
      await tester.pumpAndSettle();
      expect((await repo.findById(saved.id))!.scanMode, ScanMode.research);
      await tester.ensureVisible(find.text('レポートを作成'));
      await tester.tap(find.text('レポートを作成'));
      await tester.pumpAndSettle();
      final reported = (await repo.findById(saved.id))!;
      expect(reported.scanMode, ScanMode.research);
      expect(reported.aiMode, ReportMode.template);
      expect(reported.reportText, contains('計測モード：研究モード'));
      await tester.ensureVisible(find.text('ホームへ'));
      await tester.tap(find.text('ホームへ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('チェック開始'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(standard, hasLength(2));
      await close(tester);
    },
  );

  testWidgets('turning research off replaces its service before starting', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(research.single.disposes, 1);
    expect(standard, hasLength(2));
    await tester.tap(find.text('開始'));
    await tester.pump();
    expect(standard.last.starts, 1);
    expect(research.single.starts, 0);
    standard.last.finish(
      ScanSuccess(
        HealthCheckResult(
          id: 'standard',
          measuredAt: DateTime(2026, 10, 18),
          elapsed: const Duration(seconds: 15),
          faceDetected: true,
          quality: MeasurementQuality.good,
          scanMode: ScanMode.standard,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('通常モード'), findsOneWidget);
    final saved = (await repo.findById('standard'))!;
    expect(saved.scanMode, ScanMode.standard);
    expect(saved.estimatedHeartRateBpm, isNull);
    expect(saved.faceColorFeature, isNull);
    await close(tester);
  });
  testWidgets(
    'leaving during a mode change releases once and never opens the next session',
    (tester) async {
      final old = _SlowDispose();
      await open(tester, createStandard: () => old);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '開始'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      old.gate.complete();
      await tester.pumpAndSettle();
      expect(research, isEmpty);
      expect(old.disposes, 1);
      expect(await repo.loadAll(), isEmpty);
      expect(find.text('毎朝の自分を振り返る'), findsOneWidget);
      await close(tester);
    },
  );
}
