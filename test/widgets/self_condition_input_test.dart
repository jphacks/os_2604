import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/widgets/self_condition_input.dart';

void main() {
  testWidgets('未選択から1〜5を選べ、同じ選択の再タップと解除でnullを通知する', (tester) async {
    int? value;
    final changes = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SelfConditionInput(
                value: value,
                onChanged: (next) => setState(() {
                  value = next;
                  changes.add(next);
                }),
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('未選択'), findsOneWidget);
    for (var condition = 1; condition <= 5; condition++) {
      await tester.tap(find.widgetWithText(ChoiceChip, '$condition'));
      await tester.pump();
      expect(value, condition);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '$condition'))
            .selected,
        isTrue,
      );
    }
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pump();
    expect(value, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, '3'));
    await tester.pump();
    await tester.tap(find.text('選択を解除'));
    await tester.pump();
    expect(changes, [1, 2, 3, 4, 5, null, 3, null]);
    expect(find.text('未選択'), findsOneWidget);
  });
}
