import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/onboarding_screen.dart';

void main() {
  testWidgets('データ利用を説明し、次へ操作だけを呼び出し元へ通知する', (tester) async {
    var continued = 0;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onContinue: () => continued++)),
    );

    expect(find.textContaining('端末内で処理'), findsOneWidget);
    expect(find.textContaining('画像・動画は保存せず'), findsOneWidget);
    expect(find.textContaining('診断目的ではありません'), findsOneWidget);
    expect(find.textContaining('カメラ権限が必要'), findsOneWidget);
    expect(continued, 0);
    final button = find.text('説明を確認して次へ');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(continued, 1);
  });

  testWidgets('小さな画面と大きな文字でも説明と次へボタンをスクロールできる', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: OnboardingScreen(onContinue: () {}),
      ),
    );
    await tester.ensureVisible(find.text('説明を確認して次へ'));
    expect(tester.takeException(), isNull);
  });
}
