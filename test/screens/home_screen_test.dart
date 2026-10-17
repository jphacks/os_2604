import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/home_screen.dart';

void main() {
  testWidgets('実状態を表示し、各導線を対応するcallbackへ通知する', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          onStartCheck: () => calls.add('start'),
          onOpenHistory: () => calls.add('history'),
          onOpenSettings: () => calls.add('settings'),
          onShowExplanation: () => calls.add('explanation'),
        ),
      ),
    );
    expect(find.textContaining('履歴未接続'), findsOneWidget);
    expect(find.textContaining('計測・保存サービスは未接続'), findsOneWidget);
    expect(find.text('本日未実施'), findsNothing);
    for (final label in ['チェック開始', '履歴', '設定', 'アプリの説明']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(calls, ['start', 'history', 'settings', 'explanation']);
  });

  testWidgets('説明callback省略時は説明導線を表示しない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          onStartCheck: () {},
          onOpenHistory: () {},
          onOpenSettings: () {},
        ),
      ),
    );
    expect(find.text('アプリの説明'), findsNothing);
  });

  testWidgets('小画面と大きい文字でも最後の導線を操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HomeScreen(
          onStartCheck: () {},
          onOpenHistory: () {},
          onOpenSettings: () => opened = true,
        ),
      ),
    );
    await tester.ensureVisible(find.text('設定'));
    await tester.tap(find.text('設定'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
