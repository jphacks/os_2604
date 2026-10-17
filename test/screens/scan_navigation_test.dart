import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/health_check_result.dart';
import 'package:os_2604/models/scan_contract.dart';
import 'package:os_2604/navigation/app_routes.dart';
import 'package:os_2604/screens/scan_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';

import '../support/fake_scan.dart';

class _Scan extends FakeScanService {
  Completer<void>? cancelGate;
  bool failCancel = false;

  @override
  Future<void> cancelScan() async {
    cancels++;
    await cancelGate?.future;
    if (failCancel) {
      failCancel = false;
      throw StateError('cleanup failed');
    }
  }
}

class _Repository extends HealthRecordRepository {
  _Repository(super.database);
  Completer<void>? insertGate;
  bool fail = false;
  final attempts = <HealthCheckResult>[];

  @override
  Future<void> insert(HealthCheckResult result) async {
    attempts.add(result);
    await insertGate?.future;
    if (fail) throw StateError('save failed');
    await super.insert(result);
  }
}

class _Observer extends NavigatorObserver {
  int pops = 0;
  int replacements = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      replacements++;
}

void main() {
  late AppDatabase db;
  late _Repository repository;
  late _Scan scan;
  late _Observer observer;
  late GlobalKey<NavigatorState> navigator;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = _Repository(db);
    scan = _Scan();
    observer = _Observer();
    navigator = GlobalKey<NavigatorState>();
  });
  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home')),
        routes: {
          '/scan': (_) => ScanScreen(
            repository: repository,
            createSession: () => sessionOf(scan),
          ),
          AppRoutes.result: (context) => Scaffold(
            body: Text('result:${ModalRoute.of(context)!.settings.arguments}'),
          ),
        },
      ),
    );
    unawaited(navigator.currentState!.pushNamed('/scan'));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('開始'));
    await tester.pump();
  }

  testWidgets(
    'system back cancels once while pending and ignores late success',
    (tester) async {
      await open(tester);
      await start(tester);
      scan.cancelGate = Completer<void>();
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.tap(find.text('中止する'));
      await tester.pump();
      expect(scan.cancels, 1);
      expect(observer.pops, 0);
      scan.finish(successOutcome('late'));
      await tester.pump();
      expect(repository.attempts, isEmpty);
      scan.cancelGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(observer.pops, 1);
      expect(observer.replacements, 0);
      expect(scan.disposes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('app bar double back leaves once even if cancellation throws', (
    tester,
  ) async {
    await open(tester);
    scan.failCancel = true;
    final back = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '中止する'))
        .onPressed!;
    back();
    back();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(observer.pops, 1);
    expect(scan.disposes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('start double tap starts only one scan before rebuild', (
    tester,
  ) async {
    await open(tester);
    final begin = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    begin();
    begin();
    await tester.pump();
    expect(scan.starts, 1);
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
  });

  testWidgets('retry waits for cancellation before starting the next scan', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.poorQuality,
        elapsed: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    scan.cancelGate = Completer<void>();
    final retry = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(scan.starts, 1);
    expect(scan.cancels, 1);
    scan.cancelGate!.complete();
    await tester.pump();
    expect(scan.starts, 2);
    await tester.tap(find.text('中止する'));
    await tester.pumpAndSettle();
    expect(scan.disposes, 1);
  });

  testWidgets('leaving during retry cleanup prevents a new scan', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    scan.finish(
      const ScanFailure(
        reason: ScanFailureReason.interrupted,
        elapsed: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    scan.cancelGate = Completer<void>();
    await tester.tap(find.text('もう一度測る'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    scan.cancelGate!.complete();
    await tester.pumpAndSettle();
    expect(scan.starts, 1);
    expect(scan.disposes, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('save succeeds before exactly one result navigation', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    repository.insertGate = Completer<void>();
    scan.finish(successOutcome());
    await tester.pump();
    expect(find.text('記録を保存しています…'), findsOneWidget);
    expect(observer.replacements, 0);
    expect(await repository.findById('rec-1'), isNull);
    repository.insertGate!.complete();
    await tester.pumpAndSettle();
    expect(await repository.findById('rec-1'), isNotNull);
    expect(find.text('result:rec-1'), findsOneWidget);
    expect(observer.replacements, 1);
    expect(scan.disposes, 1);
  });

  testWidgets('back during post-save cleanup wins over result navigation', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    scan.cancelGate = Completer<void>();
    scan.finish(successOutcome());
    await tester.pumpAndSettle();
    expect(await repository.findById('rec-1'), isNotNull);
    expect(observer.replacements, 0);
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    expect(scan.cancels, 1);
    scan.cancelGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(observer.pops, 1);
    expect(observer.replacements, 0);
    expect(scan.disposes, 1);
  });

  testWidgets('failed save retries the same result only once on double tap', (
    tester,
  ) async {
    repository.fail = true;
    await open(tester);
    await start(tester);
    final result = successOutcome('same-id');
    scan.finish(result);
    await tester.pumpAndSettle();
    expect(observer.replacements, 0);
    repository.fail = false;
    repository.insertGate = Completer<void>();
    final retry = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(repository.attempts, [same(result.result), same(result.result)]);
    expect(scan.starts, 1);
    repository.insertGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('result:same-id'), findsOneWidget);
    expect((await repository.loadAll()).map((r) => r.id), ['same-id']);
    expect(observer.replacements, 1);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'back racing pending save (failure=$fail) never navigates to result',
      (tester) async {
        await open(tester);
        await start(tester);
        repository.insertGate = Completer<void>();
        repository.fail = fail;
        scan.finish(successOutcome());
        await tester.pump();
        scan.cancelGate = Completer<void>();
        await tester.binding.handlePopRoute();
        repository.insertGate!.complete();
        await tester.pump();
        expect(observer.replacements, 0);
        scan.cancelGate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
        expect(observer.pops, 1);
        expect(observer.replacements, 0);
        expect(repository.attempts, hasLength(1));
        expect(await repository.findById('rec-1'), fail ? isNull : isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets('save response after disposal (failure=$fail) is ignored', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      repository.insertGate = Completer<void>();
      repository.fail = fail;
      scan.finish(successOutcome());
      await tester.pump();
      await tester.tap(find.text('中止する'));
      await tester.pumpAndSettle();
      expect(scan.disposes, 1);
      repository.insertGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(observer.replacements, 0);
      expect(repository.attempts, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('external removal discards a late outcome and releases service', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    navigator.currentState!.removeRoute(
      ModalRoute.of(tester.element(find.byType(ScanScreen)))!,
    );
    // Resolve before the route's exit animation/disposal can finish.
    scan.finish(successOutcome('removed'));
    await tester.pumpAndSettle();
    expect(repository.attempts, isEmpty);
    expect(observer.replacements, 0);
    expect(scan.disposes, 1);
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
