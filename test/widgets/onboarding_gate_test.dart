import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/settings/onboarding_store.dart';
import 'package:os_2604/widgets/onboarding_gate.dart';

import '../support/fake_reminder.dart';

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
    reminderService: FakeReminderService(),
    reminderStore: FakeReminderStore(),
    requestCameraPermission: () async => true,
  ),
);

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 初回設定を最後まで進めて「記録をはじめる」を押す。
Future<void> acknowledge(WidgetTester tester) async {
  if (find.text('準備ができました').evaluate().isEmpty) {
    await tapText(tester, 'タップしてはじめる');
    await tapText(tester, 'つづける');
    await tapText(tester, '同意してつづける');
    await tapText(tester, '今はしない');
    await tapText(tester, 'スキップ');
  }
  final button = find.text('記録をはじめる');
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

  testWidgets('first-visit tip appears once after setup and can be closed', (
    tester,
  ) async {
    final store = FakeStore();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    await acknowledge(tester);
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(find.text('毎朝のチェックはここから'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(find.text('毎朝のチェックはここから'), findsNothing);
  });

  testWidgets('completed store bypasses explanation without another write', (
    tester,
  ) async {
    final store = FakeStore()..completed = true;
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.text('テストホーム'), findsOneWidget);
    expect(find.text('毎朝のチェックはここから'), findsNothing);
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
