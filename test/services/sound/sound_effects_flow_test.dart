import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/measure_sound_page.dart';
import 'package:os_2604/screens/onboarding_screen.dart';
import 'package:os_2604/screens/result_screen.dart';
import 'package:os_2604/ui/pachinko_effects.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/settings/feedback_settings_store.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/ui/asakao_flower.dart';

import '../../support/fake_reminder.dart';
import '../../support/fake_scan.dart';

void main() {
  late List<SoundEffect> played;
  late List<AppHaptic> felt;
  setUp(() {
    played = [];
    felt = [];
    SoundEffects.settings = const FeedbackSettings();
    SoundEffects.debugOnPlay = played.add;
    SoundEffects.debugOnHaptic = felt.add;
  });
  tearDown(() {
    SoundEffects.debugOnPlay = null;
    SoundEffects.debugOnHaptic = null;
    SoundEffects.settings = const FeedbackSettings();
  });

  test('each sound comes with its vibration; settings turn each off', () {
    SoundEffects.play(SoundEffect.ready);
    SoundEffects.play(SoundEffect.measureDone);
    SoundEffects.play(SoundEffect.pause);
    expect(played, [
      SoundEffect.ready,
      SoundEffect.measureDone,
      SoundEffect.pause,
    ]);
    // 撮影準備はすぐ計測が始まるので振動しない。
    expect(felt, [AppHaptic.heavy, AppHaptic.medium]);

    SoundEffects.settings = const FeedbackSettings(sound: false);
    SoundEffects.play(SoundEffect.measureDone);
    expect(played, hasLength(3)); // 音は止まる
    expect(felt, hasLength(3)); // 振動は鳴る

    SoundEffects.settings = const FeedbackSettings(haptics: false);
    SoundEffects.play(SoundEffect.measureDone);
    expect(played, hasLength(4));
    expect(felt, hasLength(3));
  });

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

    testWidgets('one scale note per measured second, never during a pause', (
      tester,
    ) async {
      final notes = <(MeasureInstrument, int)>[];
      SoundEffects.debugOnNote = (i, n) => notes.add((i, n));
      addTearDown(() => SoundEffects.debugOnNote = null);
      await open(tester);
      Future<void> at(int ms) async {
        scan.emit(
          ScanProgress(
            phase: ScanPhase.measuring,
            elapsed: Duration(milliseconds: ms),
          ),
        );
        await tester.pump();
      }

      await at(0); // 残り15：ド
      await at(400);
      await at(1100); // 残り14：レ
      await at(3200); // 2秒ぶん飛んでも、鳴らすのは今の1音だけ
      await at(3300);
      expect(notes, [
        (MeasureInstrument.marimba, 0),
        (MeasureInstrument.marimba, 1),
        (MeasureInstrument.marimba, 3),
      ]);
      // 届かない間（顔が外れて止まった等）は、時間がたっても鳴らない。
      await tester.pump(const Duration(seconds: 3));
      expect(notes, hasLength(3));
      await at(14100); // 最後は2オクターブ上のド
      expect(notes.last, (MeasureInstrument.marimba, 14));
      expect(felt, isEmpty); // 計測中は振動しない
      await unmount(tester);
    });

    testWidgets('no notes when sound is off or the instrument is none', (
      tester,
    ) async {
      final notes = <int>[];
      SoundEffects.debugOnNote = (_, n) => notes.add(n);
      addTearDown(() => SoundEffects.debugOnNote = null);
      SoundEffects.settings = const FeedbackSettings(
        instrument: MeasureInstrument.none,
      );
      await open(tester);
      scan.emit(
        const ScanProgress(
          phase: ScanPhase.measuring,
          elapsed: Duration(seconds: 2),
        ),
      );
      await tester.pump();
      expect(notes, isEmpty);
      await unmount(tester);
    });

    testWidgets('pachinko: saves, blacks out with its sound, then goes on', (
      tester,
    ) async {
      SoundEffects.settings = const FeedbackSettings(
        instrument: MeasureInstrument.pachinko,
      );
      await open(tester);
      scan.finish(successOutcome());
      await tester.pump(); // 結果を受け取る
      await tester.pump(); // 暗転を始める
      await tester.pump(const Duration(milliseconds: 200));
      expect(played, contains(SoundEffect.pachinkoBlackout));
      expect(played, isNot(contains(SoundEffect.measureDone)));
      // 上下の黒が閉じていく途中（閃光の前）。
      final blackout = tester.widget<PachinkoBlackout>(
        find.byType(PachinkoBlackout),
      );
      expect(blackout.progress.value, inExclusiveRange(0, 0.5));
      expect(find.text('result'), findsNothing); // 暗転の音が終わるまで進まない
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(played.last, SoundEffect.pachinkoResult);
      expect(find.text('result'), findsOneWidget);
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
    expect(felt, [AppHaptic.light]); // 花が開く瞬間に1回だけ
  });

  testWidgets('instrument picker saves, previews ドミソド and shows in settings', (
    tester,
  ) async {
    final notes = <(MeasureInstrument, int)>[];
    SoundEffects.debugOnNote = (i, n) => notes.add((i, n));
    addTearDown(() => SoundEffects.debugOnNote = null);
    final store = _MemoryFeedbackStore();
    await tester.pumpWidget(MaterialApp(home: MeasureSoundPage(store: store)));
    for (final inst in MeasureInstrument.values) {
      expect(find.text(inst.label), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('instrument-koto')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.value.instrument, MeasureInstrument.koto);
    expect(SoundEffects.settings.instrument, MeasureInstrument.koto);
    expect(notes, [
      (MeasureInstrument.koto, 0),
      (MeasureInstrument.koto, 2),
      (MeasureInstrument.koto, 4),
      (MeasureInstrument.koto, 7),
    ]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('instrument-koto')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pachinko style: bouncy notes and kyuin on completion', (
    tester,
  ) async {
    final notes = <(MeasureInstrument, int)>[];
    SoundEffects.debugOnNote = (i, n) => notes.add((i, n));
    addTearDown(() => SoundEffects.debugOnNote = null);
    final store = _MemoryFeedbackStore();
    await tester.pumpWidget(MaterialApp(home: MeasureSoundPage(store: store)));
    await tester.ensureVisible(
      find.byKey(const ValueKey('instrument-pachinko')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('instrument-pachinko')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(notes.map((e) => e.$1).toSet(), {MeasureInstrument.pachinko});
    expect(played, [SoundEffect.pachinkoBlackout]); // 試し聞きの最後に暗転の音
    expect(SoundEffects.pachinkoFinish, isTrue);
    SoundEffects.settings = SoundEffects.settings.copyWith(sound: false);
    expect(SoundEffects.pachinkoFinish, isFalse); // 効果音オフなら通常どおり
  });

  test('pachinko spreads 12 sound files over the 15 seconds in order', () {
    final files = [
      for (var i = 0; i < 15; i++) MeasureInstrument.pachinko.fileFor(i),
    ];
    expect(files.first, 'free_sound1055.mp3');
    expect(files.last, 'free_sound1066.mp3');
    expect(files.toSet(), hasLength(12)); // 12段階すべて使う
    final numbers = [
      for (final f in files) int.parse(f.replaceAll(RegExp(r'\D'), '')),
    ];
    for (var i = 1; i < numbers.length; i++) {
      expect(numbers[i], greaterThanOrEqualTo(numbers[i - 1])); // 下がらない
    }
    expect(MeasureInstrument.marimba.fileFor(3), '03.m4a');
  });

  group('result background', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<void> openResult(WidgetTester tester) async {
      final repo = HealthRecordRepository(db);
      await tester.runAsync(() => repo.insert(successOutcome().result));
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(
            repository: repo,
            aiRunner: runnerOf(FakeAiClient()),
            recordId: 'rec-1',
            onBackToHome: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('pachinko-style background and banner after the finish', (
      tester,
    ) async {
      SoundEffects.settings = const FeedbackSettings(
        instrument: MeasureInstrument.pachinko,
      );
      await openResult(tester);
      expect(find.byType(PachinkoBackground), findsOneWidget);
      expect(find.byType(PachinkoBanner), findsOneWidget);
      expect(find.text('計測できました'), findsNothing); // 見出しはバナーに置き換え
      expect(find.text('いまの体調は？'), findsOneWidget); // 入力はそのまま
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('plain background otherwise', (tester) async {
      await openResult(tester);
      expect(find.byType(PachinkoBackground), findsNothing);
      expect(find.byType(PachinkoBanner), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _MemoryFeedbackStore implements FeedbackSettingsStore {
  FeedbackSettings value = const FeedbackSettings();
  @override
  Future<FeedbackSettings> load() async => value;
  @override
  Future<void> save(FeedbackSettings settings) async => value = settings;
}
