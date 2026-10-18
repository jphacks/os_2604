import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/widgets/self_condition_input.dart';

void main() {
  testWidgets('1〜5とラベルを表示し、選択・同じ数字の再タップでnullを通知する', (tester) async {
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
    for (final label in ['とても悪い', '悪い', '普通', '良い', 'とても良い']) {
      expect(find.text(label), findsOneWidget);
    }
    for (var condition = 1; condition <= 5; condition++) {
      await tester.tap(find.text('$condition'));
      await tester.pump();
      expect(value, condition);
      expect(
        tester.getSemantics(find.text('$condition')),
        matchesSemantics(
          label: '体調 $condition / 5 ${selfConditionLabel(condition)}',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasEnabledState: false,
          isFocusable: false,
        ),
      );
    }
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(value, isNull);
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(changes, [1, 2, 3, 4, 5, null, 3, null]);
  });
}
