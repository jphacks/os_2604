import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';
import 'package:os_2604/widgets/onboarding_gate.dart';

class FakeStore implements OnboardingStore {
  bool completed = false;
  int writes = 0;
  Future<bool> Function()? read;
  Future<void> Function()? save;

  @override
  Future<bool> hasCompletedOnboarding() =>
      read?.call() ?? Future.value(completed);

  @override
  Future<void> completeOnboarding() async {
    writes++;
    if (save != null) await save!();
    completed = true;
  }
}

Widget gate(OnboardingStore store) => MaterialApp(
  home: OnboardingGate(
    store: store,
    homeBuilder: (_) => const Scaffold(body: Text('テストホーム')),
  ),
);

Future<void> acknowledge(WidgetTester tester) async {
  final button = find.text('説明を確認して次へ');
  await tester.ensureVisible(button);
  await tester.tap(button);
}

void main() {
  testWidgets(
    'initial read waits, then save completes before home; double tap is ignored',
    (tester) async {
      final read = Completer<bool>();
      final save = Completer<void>();
      final store = FakeStore();
      store.read = () => read.future;
      store.save = () => save.future;
      await tester.pumpWidget(gate(store));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      read.complete(false);
      await tester.pumpAndSettle();
      await acknowledge(tester);
      await tester.pump();
      expect(find.text('保存中…'), findsOneWidget);
      expect(find.text('テストホーム'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      expect(store.writes, 1);
      save.complete();
      await tester.pumpAndSettle();
      expect(find.text('テストホーム'), findsOneWidget);
    },
  );

  testWidgets('completed store bypasses explanation without another write', (
    tester,
  ) async {
    final store = FakeStore()..completed = true;
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(store.writes, 0);
  });

  testWidgets('read error is visible and retry re-reads persisted state', (
    tester,
  ) async {
    var attempts = 0;
    final store = FakeStore()
      ..read = () async {
        if (attempts++ == 0) throw StateError('synthetic read failure');
        return true;
      };
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.textContaining('設定を読み込めませんでした'), findsOneWidget);
    expect(find.text('テストホーム'), findsNothing);
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('write failure stays on explanation and permits retry', (
    tester,
  ) async {
    var attempts = 0;
    final store = FakeStore()
      ..save = () async {
        if (attempts++ == 0) throw StateError('synthetic write failure');
      };
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    await acknowledge(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    expect(find.text('テストホーム'), findsNothing);
    await acknowledge(tester);
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(store.writes, 2);
  });

  testWidgets('late read and late write do not update disposed widget', (
    tester,
  ) async {
    final read = Completer<bool>();
    await tester.pumpWidget(gate(FakeStore()..read = () => read.future));
    await tester.pumpWidget(const SizedBox.shrink());
    read.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final save = Completer<void>();
    await tester.pumpWidget(gate(FakeStore()..save = () => save.future));
    await tester.pumpAndSettle();
    await acknowledge(tester);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    save.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing store ignores late responses from previous store', (
    tester,
  ) async {
    final read = Completer<bool>();
    await tester.pumpWidget(gate(FakeStore()..read = () => read.future));
    await tester.pumpWidget(gate(FakeStore()..completed = true));
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    read.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
  });
}
