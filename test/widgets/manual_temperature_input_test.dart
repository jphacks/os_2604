import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/widgets/manual_temperature_input.dart';

const _range = '34.0〜42.0℃の範囲で入力してください。空欄のままでも進めます。';

void main() {
  testWidgets('34.0〜42.0と空欄だけ有効。範囲外・不正入力は古い値を消して保存不可を通知する', (tester) async {
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
    expect(find.text('手持ちの体温計で測った値を入力します。'), findsOneWidget);
    expect(find.text('カメラでは体温を測定しません。'), findsOneWidget);
    expect(find.text('任意'), findsOneWidget);
    final field = find.byType(TextFormField);
    for (final invalid in [
      '33.9',
      '42.1',
      '45.2',
      '0',
      '-1',
      'abc',
      'NaN',
      'Infinity',
      '-Infinity',
      '1e999',
    ]) {
      await tester.enterText(field, invalid);
      await tester.pump();
      expect(valid, isFalse, reason: invalid);
      expect(value, isNull, reason: invalid);
      expect(find.text(_range), findsOneWidget, reason: invalid);
      expect(tester.widget<TextFormField>(field).controller!.text, invalid);
    }
    for (final ok in ['34.0', '34', '36.7', '42.0']) {
      await tester.enterText(field, ok);
      await tester.pump();
      expect(valid, isTrue, reason: ok);
      expect(value, double.parse(ok), reason: ok);
      expect(find.text(_range), findsNothing, reason: ok);
    }
    // 空欄は有効（体温なし）。
    await tester.enterText(field, '');
    await tester.pump();
    expect(valid, isTrue);
    expect(value, isNull);
    expect(find.text(_range), findsNothing);
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(valid, isFalse);
    expect(received, isNull);
    expect(find.text(_range), findsOneWidget);
    await show(37);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '37.0',
    );
    await tester.pump();
    expect(valid, isTrue);
    expect(find.text(_range), findsNothing);
    expect(received, isNull); // 外部値の反映は入力変更として再通知しない。
  });

  testWidgets('範囲外の保存済み値で開くと、親へ保存不可を通知する', (tester) async {
    var valid = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualTemperatureInput(
            value: 45.2,
            onChanged: (_) {},
            onValidityChanged: (next) => valid = next,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(valid, isFalse);
    expect(find.text(_range), findsOneWidget);
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
