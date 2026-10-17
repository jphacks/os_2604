import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/widgets/manual_temperature_input.dart';

void main() {
  testWidgets('有限数と任意の空欄を受け入れ、不正入力では古い値を消して保存不可を通知する', (tester) async {
    double? value = 36.5;
    var valid = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ManualTemperatureInput(
              value: value,
              onChanged: (next) => setState(() => value = next),
              onValidityChanged: (next) => valid = next,
            ),
          ),
        ),
      ),
    );
    expect(find.text('外部の体温計による手入力'), findsOneWidget);
    expect(find.text('カメラでは体温を測定しません'), findsOneWidget);
    final field = find.byType(TextFormField);
    for (final invalid in ['abc', 'NaN', 'Infinity', '-Infinity', '1e999']) {
      await tester.enterText(field, invalid);
      await tester.pump();
      expect(valid, isFalse, reason: invalid);
      expect(value, isNull);
      expect(find.text('有限の数値を入力してください'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, invalid);
    }
    for (final finite in ['0', '-1', '1000', '36.7']) {
      await tester.enterText(field, finite);
      await tester.pump();
      expect(valid, isTrue);
      expect(value, double.parse(finite));
      expect(find.text('有限の数値を入力してください'), findsNothing);
    }
    await tester.tap(find.text('入力を消す'));
    await tester.pump();
    expect(valid, isTrue);
    expect(value, isNull);
    expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
  });

  testWidgets('不正入力後の親値更新だけで有効性とエラー表示が回復する', (tester) async {
    double? received;
    var valid = true;
    Future<void> show(double? value) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualTemperatureInput(
            value: value,
            onChanged: (next) => received = next,
            onValidityChanged: (next) => valid = next,
          ),
        ),
      ),
    );
    await show(36.5);
    await tester.enterText(find.byType(TextFormField), 'bad');
    await tester.tap(find.text('入力を確認'));
    await tester.pump();
    expect(valid, isFalse);
    expect(received, isNull);
    await show(37);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '37.0',
    );
    expect(valid, isTrue);
    await tester.pump();
    expect(find.text('有限の数値を入力してください'), findsNothing);
    expect(received, isNull); // 外部値の反映は入力変更として再通知しない。
  });

  testWidgets('連続外部更新は最新値だけ通知し、破棄後は通知しない', (tester) async {
    final notifications = <bool>[];
    ManualTemperatureInput input(double value) => ManualTemperatureInput(
      value: value,
      onChanged: (_) {},
      onValidityChanged: notifications.add,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: input(36))));
    final element = tester.element(find.byType(ManualTemperatureInput));
    element.owner!.buildScope(tester.binding.rootElement!, () {
      element.update(input(37));
      element.update(input(38));
    });
    await tester.pump();
    expect(notifications, [true]);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '38.0',
    );

    notifications.clear();
    element.owner!.buildScope(
      tester.binding.rootElement!,
      () => element.update(input(39)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(notifications, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
