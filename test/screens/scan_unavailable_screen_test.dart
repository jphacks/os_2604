import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/scan_unavailable_screen.dart';

void main() {
  testWidgets('未接続状態だけを説明し、小画面・大きい文字でもホームへ戻れる', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var returned = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ScanUnavailableScreen(onBackToHome: () => returned++),
      ),
    );
    expect(find.textContaining('カメラ・計測サービスが未接続'), findsOneWidget);
    expect(find.textContaining('撮影・計測・記録の保存は行いません'), findsOneWidget);
    expect(find.textContaining('カメラ権限がない'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(returned, 0);
    await tester.ensureVisible(find.text('ホームへ戻る'));
    await tester.tap(find.text('ホームへ戻る'));
    expect(returned, 1);
    expect(tester.takeException(), isNull);
  });
}
