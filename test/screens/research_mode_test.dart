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
import 'package:os_2604/ui/asakao_widgets.dart';

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

  /// 設定タブを開き、研究モードの行からページへ進む。
  Future<void> openResearch(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('main-tab-2')));
    await t.pumpAndSettle();
    await t.tap(find.text('研究モード'));
    await t.pumpAndSettle();
  }

  bool researchOn(WidgetTester t) =>
      t.widget<Switch>(find.byType(Switch)).value;

  Future<void> back(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('subpage-back')));
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
    expect(find.byType(Switch), findsNothing);
    await close(t);
  });
  testWidgets(
    'settings persists research; camera auto-starts it and saves mode with null estimates',
    (t) async {
      await open(t);
      await openResearch(t);
      expect(researchOn(t), isFalse);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(researchOn(t), isTrue);
      expect(
        await t.runAsync(() => DriftScanModeStore(db).loadResearchMode()),
        isTrue,
      );
      // 設定のトップに戻ると、行の値もオンになる。
      await back(t);
      expect(
        find.descendant(
          of: find.widgetWithText(AsakaoListRow, '研究モード'),
          matching: find.text('オン'),
        ),
        findsOneWidget,
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
      await openResearch(t);
      expect(researchOn(t), isTrue);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(researchOn(t), isFalse);
      await back(t);
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
    await openResearch(t);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(researchOn(t), isFalse);
    expect(find.textContaining('計測モードを保存できませんでした'), findsOneWidget);
    await back(t);
    expect(
      find.descendant(
        of: find.widgetWithText(AsakaoListRow, '研究モード'),
        matching: find.text('オフ'),
      ),
      findsOneWidget,
    );
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
  testWidgets(
    'read failure leaves the row without a value and says so on the page',
    (t) async {
      await open(t, store: _FailStore());
      await openResearch(t);
      expect(find.text('計測モードを読み込めませんでした'), findsOneWidget);
      expect(find.text('計測モードを再読み込み'), findsOneWidget);
      expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await back(t);
      final row = find.widgetWithText(AsakaoListRow, '研究モード');
      expect(row, findsOneWidget);
      for (final value in ['オン', 'オフ']) {
        expect(
          find.descendant(of: row, matching: find.text(value)),
          findsNothing,
        );
      }
      await close(t);
    },
  );

  testWidgets('research page explains the limits and returns to settings', (
    t,
  ) async {
    await open(t);
    await openResearch(t);
    for (final text in [
      '実験的な機能',
      '次回の撮影から適用されます',
      'ご利用前に',
      '診断には使用できません。値は参考値です。',
      '計測品質が不足したときは「未測定」になります。',
      'オンにしても映像は保存されません。処理はこの端末の中で行います。',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await back(t);
    expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);
    await close(t);
  });
}
