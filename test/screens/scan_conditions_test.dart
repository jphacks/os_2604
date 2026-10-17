import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

import '../support/fake_scan.dart';

/// テスト末尾で画面を外し、計測サービスの後始末まで流す。
void tw(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

void main() {
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
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, ScanProgress p) async {
    scan.emit(p);
    await tester.pump();
  }

  Finder text(String t) => find.text(t);

  tw('idle: title, unchecked conditions and button-fitting caption', (
    tester,
  ) async {
    await open(tester);
    expect(text('顔の位置合わせ'), findsOneWidget);
    expect(text('枠の中に顔を合わせてください'), findsOneWidget);
    expect(text('顔'), findsOneWidget);
    expect(text('明るさ'), findsOneWidget);
    expect(text('角度'), findsOneWidget);
    expect(text('未確認'), findsNWidgets(3)); // 何も判定していないので緑にしない
    expect(text('開始を押すと、カメラで3つの条件を確認します'), findsOneWidget);
    expect(find.textContaining('自動で計測が始まります'), findsNothing);
    expect(text('中止する'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  tw('conditions follow C guidance and never fake a green check', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.faceNotFound,
      ),
    );
    expect(text('未検出'), findsOneWidget);
    expect(text('確認中'), findsNWidgets(2)); // 明るさ・角度はまだ判定されていない
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.lowLight,
      ),
    );
    expect(text('検出'), findsOneWidget); // 顔は見つかっている
    expect(text('不足'), findsOneWidget);
    expect(text('確認中'), findsOneWidget); // 角度は未判定
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.textContaining('明るい場所に移動'), findsOneWidget);

    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.offAngle,
      ),
    );
    expect(text('検出'), findsOneWidget);
    expect(text('十分'), findsOneWidget);
    expect(text('要正面'), findsOneWidget);

    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.faceTooSmall,
      ),
    );
    expect(text('遠い'), findsOneWidget);
    expect(text('十分'), findsOneWidget);
    expect(text('正面'), findsOneWidget);
  });

  tw('all three turn green only after a guidance issue has cleared', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    // 最初のフレーム前の guidance なしは「条件OK」とは限らない。
    await emit(tester, const ScanProgress(phase: ScanPhase.preparing));
    expect(text('確認中'), findsNWidgets(3));
    expect(find.byIcon(Icons.check), findsNothing);
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.offCenter,
      ),
    );
    await emit(tester, const ScanProgress(phase: ScanPhase.preparing));
    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(text('検出'), findsOneWidget);
    expect(text('十分'), findsOneWidget);
    expect(text('正面'), findsOneWidget);
  });

  tw('measuring: pill, ring seconds from C progress, no invented quality', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.measuring,
        elapsed: Duration(seconds: 6),
      ),
    );
    expect(text('計測中'), findsOneWidget);
    expect(text('そのまま動かずに'), findsOneWidget);
    expect(text('9'), findsOneWidget);
    expect(text('残り'), findsOneWidget);
    expect(find.textContaining('品質'), findsNothing); // 実データが無いので出さない
    expect(find.widgetWithText(FilledButton, '開始'), findsNothing);
    expect(text('中止する'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(3));
  });

  tw('preparing to countdown retains the camera without cancelling', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.offCenter,
      ),
    );
    expect(scan.cancels, 0);
    await emit(tester, const ScanProgress(phase: ScanPhase.measuring));
    expect(scan.cancels, 0);
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.measuring,
        elapsed: Duration(seconds: 1),
      ),
    );
    expect(scan.cancels, 0);
  });

  tw('failure screen: invalid chip, reason card and honest note', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.faceNotFound,
        elapsed: Duration(seconds: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(text('この計測は無効になりました'), findsOneWidget);
    expect(text('計測を中断しました'), findsOneWidget);
    expect(text('うまく計測できませんでした'), findsOneWidget);
    expect(find.textContaining('位置を調整'), findsOneWidget);
    expect(text('途中までのデータは保存されません。'), findsOneWidget);
    expect(text('もう一度測る'), findsOneWidget);
    expect(text('履歴に戻る'), findsOneWidget);
  });

  tw('permission denied keeps its guidance and has no 計測 invalid chip', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(text('開始'));
    await tester.pump();
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.permissionDenied,
        elapsed: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(text('この計測は無効になりました'), findsNothing);
    expect(text('カメラの許可が必要です'), findsOneWidget);
    expect(find.textContaining('設定アプリから許可してください'), findsOneWidget);
    expect(text('もう一度測る'), findsOneWidget);
  });

  tw('small phone: no overflow while aligning, measuring and failing', (
    tester,
  ) async {
    await open(tester);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await tester.tap(text('開始'));
    await tester.pump();
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.preparing,
        guidance: ScanGuidance.lowLight,
      ),
    );
    await emit(
      tester,
      const ScanProgress(
        phase: ScanPhase.measuring,
        elapsed: Duration(seconds: 3),
      ),
    );
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.interrupted,
        elapsed: Duration(seconds: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
