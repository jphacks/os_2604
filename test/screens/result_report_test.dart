import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/screens/result_screen.dart';
import 'package:os_2604/services/ai/on_device_ai_client.dart';
import 'package:os_2604/services/db/app_database.dart';

import '../support/fake_scan.dart';

const _range = '34.0〜42.0℃の範囲で入力してください。空欄のままでも進めます。';

/// テスト末尾で画面を外す（生成待ちなどを残さない）。
void tw(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

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

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '結果を見る'));

  Future<void> addPast(List<(String, int, int?)> rows) async {
    for (final (id, day, condition) in rows) {
      await repo.insert(
        HealthCheckResult(
          id: id,
          measuredAt: DateTime(2026, 10, day, 8, 0),
          elapsed: const Duration(seconds: 15),
          faceDetected: true,
          quality: MeasurementQuality.good,
          selfCondition: condition,
        ),
      );
    }
  }

  tw('self report: condition 1..5 each saved to the same record', (
    tester,
  ) async {
    for (var c = 1; c <= 5; c++) {
      // 周回ごとに入力・レポートのない状態へ戻す。
      await repo.updateInputsAndReport(successOutcome().result);
      await tester.pumpWidget(const SizedBox()); // 画面状態を作り直す
      await open(tester);
      await press(tester, '$c');
      await press(tester, '結果を見る');
      await tester.pumpAndSettle();
      expect((await repo.findById('rec-1'))!.selfCondition, c);
      expect(await repo.loadAll(), hasLength(1));
    }
  });

  tw('clearing condition and temperature saves null and no source', (
    tester,
  ) async {
    await repo.updateSelfCondition('rec-1', 3);
    await repo.updateTemperature('rec-1', 36.5, TemperatureSource.manual);
    await open(tester);
    await press(tester, '3'); // 選択中の数字をもう一度押すと解除
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.selfCondition, isNull);
    expect(saved.bodyTemperatureC, isNull);
    expect(saved.temperatureSource, TemperatureSource.none);
  });

  tw(
    'temperature 33.9/42.1/invalid disable the button; blank/34.0/42.0 allow',
    (tester) async {
      await open(tester);
      final field = find.byType(TextFormField);
      for (final text in ['33.9', '42.1', 'abc', 'NaN', '1e999', '0', '-1']) {
        await tester.enterText(field, text);
        await tester.pump();
        expect(submitButton(tester).onPressed, isNull, reason: text);
        expect(find.text(_range), findsOneWidget, reason: text);
        expect((await repo.findById('rec-1'))!.bodyTemperatureC, isNull);
      }
      await tester.enterText(field, '');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull); // 空欄でも進める
      expect(find.text(_range), findsNothing);
      await tester.enterText(field, '34.0');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);
      await tester.enterText(field, '42.0');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);
      await press(tester, '結果を見る');
      await tester.pumpAndSettle();
      final saved = (await repo.findById('rec-1'))!;
      expect(saved.bodyTemperatureC, 42.0);
      expect(saved.temperatureSource, TemperatureSource.manual);
      expect(find.text('42.0℃'), findsOneWidget);
    },
  );

  tw('failed input save keeps draft on the input screen and can retry', (
    tester,
  ) async {
    await open(tester);
    await press(tester, '4');
    await tester.enterText(find.byType(TextFormField), '36.5');
    await tester.pump();
    repo.failUpdate = true;
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.textContaining('入力を保存できませんでした'), findsOneWidget);
    expect(find.text('いまの体調は？'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '36.5',
    );
    expect(ai.generations, 0); // 保存に失敗したら生成へ進まない
    repo.failUpdate = false;
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.selfCondition, 4);
    expect(saved.bodyTemperatureC, 36.5);
  });

  tw('pending save ignores repeat requests', (tester) async {
    await open(tester);
    await press(tester, '3');
    repo.inputGate = Completer<void>();
    final submit = submitButton(tester).onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);
    repo.inputGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.inputWrites, 1);
    expect((await repo.findById('rec-1'))!.reportText, isNotNull);
  });

  tw('deletion during save does not recreate the record', (tester) async {
    await open(tester);
    repo.inputGate = Completer<void>();
    await press(tester, '4');
    await press(tester, '結果を見る');
    await repo.delete('rec-1');
    repo.inputGate!.complete();
    await tester.pumpAndSettle();
    expect(await repo.findById('rec-1'), isNull);
    expect(find.textContaining('入力を保存できませんでした'), findsOneWidget);
    expect(find.text('いまの体調は？'), findsOneWidget);
  });

  tw('pressing 結果を見る shows the generating screen and the template link', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('レポートを書いています…'), findsOneWidget);
    expect(find.text('記録は保存済みです。'), findsOneWidget);
    expect(find.text('まとめは数秒で表示されます。'), findsOneWidget);
    expect(find.text('定型文で先に見る'), findsOneWidget);
    // 生成前に記録（入力）は保存済み。
    expect(await repo.findById('rec-1'), isNotNull);
    await tester.tap(find.text('定型文で先に見る'));
    await tester.pumpAndSettle();
    expect(ai.cancellations, isNotEmpty); // AIの生成を止める
    expect(find.text('定型文'), findsOneWidget);
    expect(find.text('先に定型文で表示しています'), findsOneWidget);
    expect(find.text('レポートを書いています…'), findsNothing);
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.template);
    ai.generationGate!.complete('reviewRecord'); // 遅れて返っても反映しない
    await tester.pumpAndSettle();
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.template);
  });

  tw('template fallback is saved and labelled with a reason', (tester) async {
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('定型文'), findsOneWidget);
    expect(find.textContaining('端末内AIを使えないため'), findsOneWidget);
    expect(find.text('端末内AIで作成'), findsNothing);
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.reportText, isNotNull);
    expect(saved.aiMode, ReportMode.template);
  });

  tw('on-device success is saved and labelled', (tester) async {
    ai.availability = AiAvailability.available;
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('端末内AIで作成'), findsOneWidget);
    expect(find.textContaining('定型文で表示しています'), findsNothing);
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.onDevice);
  });

  tw('the condition entered on the input screen is used for generation', (
    tester,
  ) async {
    ai.availability = AiAvailability.available;
    await open(tester);
    await press(tester, '4');
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(ai.prompt, contains('"selfCondition":4'));
  });

  tw('report DB failure shows the failure screen without 通信 wording', (
    tester,
  ) async {
    repo.failReport = true;
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('まとめを作れませんでした'), findsOneWidget);
    expect(find.text('今日の記録は保存済みなので、定型文で結果を確認できます。'), findsOneWidget);
    expect(find.textContaining('通信'), findsNothing);
    expect(find.text('定型文で結果を見る'), findsOneWidget);
    expect(find.text('もう一度試す'), findsOneWidget);
    expect((await repo.findById('rec-1'))!.reportText, isNull);
    // 保存できない間は結果へ進まず、失敗画面に留まる。
    await tester.tap(find.text('定型文で結果を見る'));
    await tester.pumpAndSettle();
    expect(find.text('まとめを作れませんでした'), findsOneWidget);
    repo.failReport = false;
    await tester.tap(find.text('定型文で結果を見る'));
    await tester.pumpAndSettle();
    expect(find.text('定型文'), findsOneWidget);
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.template);
  });

  tw('retry from the failure screen generates again', (tester) async {
    ai.availability = AiAvailability.available;
    repo.failReport = true;
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('まとめを作れませんでした'), findsOneWidget);
    repo.failReport = false;
    await tester.tap(find.text('もう一度試す'));
    await tester.pumpAndSettle();
    expect(find.text('端末内AIで作成'), findsOneWidget);
    expect((await repo.findById('rec-1'))!.aiMode, ReportMode.onDevice);
  });

  tw('record deleted during generation is not resurrected', (tester) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await repo.delete('rec-1');
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect(await repo.findById('rec-1'), isNull);
    expect(find.text('まとめを作れませんでした'), findsOneWidget);
    expect(find.text('端末内AIで作成'), findsNothing);
  });

  tw('leaving during generation cancels and writes nothing', (tester) async {
    ai.availability = AiAvailability.available;
    ai.generationGate = Completer();
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    ai.generationGate!.complete('reviewRecord');
    await tester.pumpAndSettle();
    expect(ai.cancellations, isNotEmpty);
    expect((await repo.findById('rec-1'))!.reportText, isNull);
  });

  tw('report text includes accumulating status when history is insufficient', (
    tester,
  ) async {
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    final saved = (await repo.findById('rec-1'))!;
    expect(saved.reportText, contains('過去比較：基準値蓄積中（有効記録 0/3件）'));
    expect(find.textContaining('過去比較：基準値蓄積中（有効記録 0/3件）'), findsOneWidget);
  });

  tw('baseline accumulating card shows n/3 from past self-reported records', (
    tester,
  ) async {
    await addPast([('past-1', 15, 3), ('past-2', 16, null)]);
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('基準値を蓄積中'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('あと2件、体調つきで記録すると普段との比較を表示します。'), findsOneWidget);
    expect(find.text('今日の記録ができました'), findsOneWidget);
    expect(find.textContaining('普段'), findsNWidgets(1)); // カード内の1か所のみ
  });

  tw('no past records: 0 / 3 and no comparison caption', (tester) async {
    await open(tester);
    await press(tester, '4');
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.text('普段どおり'), findsNothing);
    expect(find.text('いつもどおりの朝です'), findsNothing);
  });

  tw('baseline median appears as a caption only from real past records', (
    tester,
  ) async {
    await addPast([('past-1', 14, 2), ('past-2', 15, 3), ('past-3', 16, 5)]);
    await open(tester);
    await press(tester, '4'); // 中央値3 → +1
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('基準値を蓄積中'), findsNothing);
    expect(find.text('普段より +1'), findsOneWidget);
    expect(find.text('今日の記録ができました'), findsOneWidget);
    expect(find.text('いつもどおりの朝です'), findsNothing);
  });

  tw('headline says いつもどおり only when today equals the baseline', (
    tester,
  ) async {
    await addPast([('past-1', 14, 2), ('past-2', 15, 3), ('past-3', 16, 5)]);
    await open(tester);
    await press(tester, '3'); // 中央値3と同じ
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('いつもどおりの朝です'), findsOneWidget);
    expect(find.text('普段どおり'), findsOneWidget);
  });

  tw('estimated heart rate is shown only when the record has one', (
    tester,
  ) async {
    await open(tester);
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.textContaining('推定心拍'), findsNothing);
    expect(find.textContaining('bpm'), findsNothing);
  });

  tw('estimated heart rate row shows value, 参考値 and its source', (
    tester,
  ) async {
    await repo.delete('rec-1');
    await repo.insert(
      HealthCheckResult(
        id: 'rec-1',
        measuredAt: DateTime(2026, 10, 17, 8, 30),
        elapsed: const Duration(seconds: 15, milliseconds: 200),
        faceDetected: true,
        quality: MeasurementQuality.good,
        estimatedHeartRateBpm: 68.4,
        heartRateSource: HeartRateSource.rppgExperimental,
        reportText: '保存済みレポート',
        aiMode: ReportMode.template,
      ),
    );
    await open(tester);
    // レポート済みの記録（履歴から開く場合）は結果を直接表示する。
    expect(find.text('いまの体調は？'), findsNothing);
    expect(find.text('推定心拍'), findsOneWidget);
    expect(find.text('参考値'), findsOneWidget);
    expect(find.text('カメラから推定（研究モード）'), findsOneWidget);
    expect(find.text('68 bpm'), findsOneWidget);
    expect(find.text('保存済みレポート'), findsOneWidget);
    expect(find.text('10月17日（土） 8:30'), findsOneWidget);
  });

  tw('small phone: input, generating and result fit without overflow', (
    tester,
  ) async {
    await open(tester);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await press(tester, '4');
    await tester.enterText(find.byType(TextFormField), '45.2');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField), '36.4');
    await tester.pump();
    await press(tester, '結果を見る');
    await tester.pumpAndSettle();
    expect(find.text('履歴に戻る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
