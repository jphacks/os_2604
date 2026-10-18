import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/onboarding_screen.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/ui/asakao_flower.dart';

import '../../support/fake_reminder.dart';
import '../../support/fake_scan.dart';

void main() {
  late List<SoundEffect> played;
  setUp(() {
    played = [];
    SoundEffects.debugOnPlay = played.add;
  });
  tearDown(() => SoundEffects.debugOnPlay = null);

  group('scan', () {
    late AppDatabase db;
    late FakeScanService scan;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      scan = FakeScanService();
    });
    tearDown(() async => db.close());

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ScanScreen(
            repository: HealthRecordRepository(db),
            createSession: () => sessionOf(scan),
          ),
          routes: {AppRoutes.result: (_) => const Text('result')},
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('ready once when the three checks turn green, then done', (
      tester,
    ) async {
      await open(tester);
      scan.emit(
        const ScanProgress(
          phase: ScanPhase.preparing,
          guidance: ScanGuidance.lowLight,
        ),
      );
      await tester.pump();
      expect(played, isEmpty); // まだそろっていない
      scan.emit(const ScanProgress(phase: ScanPhase.preparing));
      await tester.pump();
      expect(played, [SoundEffect.ready]);
      scan.emit(
        const ScanProgress(
          phase: ScanPhase.measuring,
          elapsed: Duration(seconds: 1),
        ),
      );
      await tester.pump();
      expect(played, [SoundEffect.ready]); // 1回だけ
      scan.finish(successOutcome());
      await tester.pumpAndSettle();
      expect(played, [SoundEffect.ready, SoundEffect.measureDone]);
      await unmount(tester);
    });

    testWidgets('pause sound when the interruption screen (3-3) shows', (
      tester,
    ) async {
      await open(tester);
      scan.finish(
        const ScanFailure(
          reason: ScanFailureReason.interrupted,
          elapsed: Duration(seconds: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(played, [SoundEffect.pause]);
      await unmount(tester);
    });
  });

  testWidgets('setup done sound only on the completion page (1-7)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onFinish: () {},
          reminderService: FakeReminderService(),
          reminderStore: FakeReminderStore(),
          requestCameraPermission: () async => true,
        ),
      ),
    );
    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tap('タップしてはじめる');
    await tap('つづける');
    await tap('同意してつづける');
    await tap('カメラを許可する');
    expect(played, isEmpty);
    await tap('スキップ');
    expect(find.text('準備ができました'), findsOneWidget);
    expect(played, [SoundEffect.setupDone]);
  });

  testWidgets('bloom sound when today bud opens, not when already bloomed', (
    tester,
  ) async {
    Future<void> show({required bool bloomed}) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AsakaoTodayBloom(bloomed: bloomed, visible: true),
      ),
    );
    await show(bloomed: true);
    expect(played, isEmpty);
    await show(bloomed: false);
    await show(bloomed: true);
    await tester.pumpAndSettle();
    expect(played, [SoundEffect.bloom]);
  });
}
