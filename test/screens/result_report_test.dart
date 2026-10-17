import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/result_screen.dart';
import 'package:os_2604/services/ai/on_device_ai_client.dart';
import 'package:os_2604/services/db/app_database.dart';

import '../support/fake_scan.dart';

void main() {
  late AppDatabase db;
  late FlakyRepository repo;
  late FakeAiClient ai;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FlakyRepository(db);
    ai = FakeAiClient();
    await repo.insert(successOutcome().result);
  });
  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          repository: repo,
          aiRunner: runnerOf(ai),
          recordId: 'rec-1',
          onBackToHome: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('condition 1..5 and clearing update the same record', (
    tester,
  ) async {
    await open(tester);
    for (var c = 1; c <= 5; c++) {
      await press(tester, '$c');
      await press(tester, '体調を保存');
      await tester.pumpAndSettle();
      expect((await repo.findById('rec-1'))!.selfCondition, c);
    }
    await press(tester, '選択を解除');
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.selfCondition, isNull);
    expect(await repo.loadAll(), hasLength(1));
    expect(find.text('体調を保存しました'), findsOneWidget);
  });

  testWidgets(
    'temperature rejects invalid text and saves changes and null source',
    (tester) async {
      await open(tester);
      final field = find.byType(TextFormField);
      for (final text in ['abc', 'NaN', 'Infinity', '1e999', '0', '-1']) {
        await tester.enterText(field, text);
        await tester.pump();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, '体温を保存'),
              )
              .onPressed,
          isNull,
        );
        expect((await repo.findById('rec-1'))!.bodyTemperatureC, isNull);
      }
      for (final t in [36.5, 37.0]) {
        await tester.enterText(field, '$t');
        await tester.pump();
        await press(tester, '体温を保存');
        await tester.pumpAndSettle();
        expect((await repo.findById('rec-1'))!.bodyTemperatureC, t);
        expect(
          (await repo.findById('rec-1'))!.temperatureSource,
          TemperatureSource.manual,
        );
        expect(find.text('$t ℃（手入力）'), findsOneWidget);
      }
      await press(tester, '入力を消す');
      await press(tester, '体温を保存');
      await tester.pumpAndSettle();
      final saved = (await repo.findById('rec-1'))!;
      expect(saved.bodyTemperatureC, isNull);
      expect(saved.temperatureSource, TemperatureSource.none);
    },
  );

  testWidgets('failed clear keeps draft and can retry', (tester) async {
    await repo.updateSelfCondition('rec-1', 3);
    await repo.updateTemperature('rec-1', 36.5, TemperatureSource.manual);
    await open(tester);
    repo.failUpdate = true;
    await press(tester, '選択を解除');
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    expect(find.textContaining('体調を保存できませんでした'), findsOneWidget);
    expect(find.text('未選択'), findsOneWidget);
    expect((await repo.findById('rec-1'))!.selfCondition, 3);
    await press(tester, '入力を消す');
    await press(tester, '体温を保存');
    await tester.pumpAndSettle();
    expect(find.textContaining('体温を保存できませんでした'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
    repo.failUpdate = false;
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    await press(tester, '体温を保存');
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.selfCondition, isNull);
    expect((await repo.findById('rec-1'))!.bodyTemperatureC, isNull);
  });

  testWidgets('pending save ignores repeat requests and keeps newer draft', (
    tester,
  ) async {
    await open(tester);
    await press(tester, '3');
    repo.inputGate = Completer<void>();
    final save = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '体調を保存'))
        .onPressed!;
    save();
    save();
    await tester.pump();
    await press(tester, '4');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'レポートを作成'),
          )
          .onPressed,
      isNull,
    );
    repo.inputGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.inputWrites, 1);
    expect(find.text('選択中：4 / 5'), findsOneWidget);
    expect(find.text('体調を保存しました'), findsNothing);
    repo.inputGate = null;
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.selfCondition, 4);
  });

  testWidgets('deletion during save does not recreate record or show success', (
    tester,
  ) async {
    await open(tester);
    repo.inputGate = Completer<void>();
    await press(tester, '4');
    await press(tester, '体調を保存');
    await repo.delete('rec-1');
    repo.inputGate!.complete();
    await tester.pumpAndSettle();
    expect(await repo.findById('rec-1'), isNull);
    expect(find.textContaining('体調を保存できませんでした'), findsOneWidget);
  });

  testWidgets('editing without saving discards pending generation', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, 'レポートを作成');
    await press(tester, '4');
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.reportText, isNull);
    expect(find.text('選択中：4 / 5'), findsOneWidget);
  });

  testWidgets(
    'report persistence blocks saves then input save clears stale report',
    (tester) async {
      repo.reportGate = Completer<void>();
      await open(tester);
      await press(tester, 'レポートを作成');
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '体調を保存'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '体温を保存'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      repo.reportGate!.complete();
      await tester.pumpAndSettle();
      expect((await repo.findById('rec-1'))!.reportText, isNotNull);
      await press(tester, '4');
      await press(tester, '体調を保存');
      await tester.pumpAndSettle();
      expect((await repo.findById('rec-1'))!.reportText, isNull);
      expect(find.text('レポートは未生成です。'), findsOneWidget);
    },
  );

  testWidgets('template fallback is saved and labelled with a reason', (
    tester,
  ) async {
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pumpAndSettle();
    expect(find.text('定型文で作成'), findsOneWidget);
    expect(find.textContaining('端末内AIを使えないため'), findsOneWidget);
    expect(find.text('レポートは未生成です。'), findsNothing);
    expect(find.text('レポートを作り直す'), findsOneWidget);
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.reportText, isNotNull);
    expect(saved.aiMode, ReportMode.template);
  });

  testWidgets('on-device success is saved and labelled', (tester) async {
    ai.availability = AiAvailability.available;
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pumpAndSettle();
    expect(find.text('端末内AIで作成'), findsOneWidget);
    expect(find.textContaining('定型文で表示しています'), findsNothing);
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.onDevice);
  });

  testWidgets('latest saved self condition is used for generation', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    await open(tester);
    await tester.tap(find.text('4'));
    await tester.pump();
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    await press(tester, 'レポートを作成');
    await tester.pumpAndSettle();
    expect(ai.prompt, contains('"selfCondition":4'));
  });

  testWidgets('input saved during generation discards the late result', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pump();
    expect(find.text('レポートを作成しています…'), findsOneWidget);
    await tester.tap(find.text('4'));
    await tester.pump();
    await press(tester, '体調を保存');
    await tester.pumpAndSettle();
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.reportText, isNull);
    expect(find.text('レポートを作成'), findsOneWidget);
    expect(ai.cancellations, isNotEmpty);
  });

  testWidgets('record deleted during generation is not resurrected', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pump();
    await repo.delete('rec-1');
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect(await repo.findById('rec-1'), isNull);
    expect(find.textContaining('レポートを作成できませんでした'), findsOneWidget);
    expect(find.text('端末内AIで作成'), findsNothing);
  });

  testWidgets('report DB failure is shown as failure', (tester) async {
    repo.failReport = true;
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pumpAndSettle();
    expect(find.textContaining('レポートを作成できませんでした'), findsOneWidget);
    expect(find.text('定型文で作成'), findsNothing);
    expect((await repo.findById('rec-1'))!.reportText, isNull);
  });

  testWidgets('leaving during generation cancels and writes nothing', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, 'レポートを作成');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect(ai.cancellations, isNotEmpty);
    expect((await repo.findById('rec-1'))!.reportText, isNull);
  });
}
