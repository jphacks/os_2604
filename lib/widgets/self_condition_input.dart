import 'package:flutter/material.dart';

import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// 体調（1〜5）の表示ラベル。入力・結果画面で共通。
String selfConditionLabel(int condition) => switch (condition) {
  1 => 'とても悪い',
  2 => '悪い',
  3 => '普通',
  4 => '良い',
  5 => 'とても良い',
  _ => throw RangeError.range(condition, 1, 5, 'condition'),
};

/// 任意の自己申告（1〜5）。値の保持・保存は呼び出し元が扱う。
/// 選択中の数字をもう一度押すと未選択（null）に戻る。
class SelfConditionInput extends StatelessWidget {
  const SelfConditionInput({
    super.key,
    required this.value,
    required this.onChanged,
  }) : assert(value == null || (value >= 1 && value <= 5));

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AsakaoCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var condition = 1; condition <= 5; condition++)
            Expanded(child: _option(condition)),
        ],
      ),
    );
  }

  Widget _option(int condition) {
    final selected = value == condition;
    final label = selfConditionLabel(condition);
    return Semantics(
      button: true,
      selected: selected,
      label: '体調 $condition / 5 $label',
      excludeSemantics: true,
      onTap: () => onChanged(selected ? null : condition),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(selected ? null : condition),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AsakaoStyle.coral : AsakaoStyle.card,
                  border: Border.all(
                    color: selected ? AsakaoStyle.coral : AsakaoStyle.border,
                    width: 2,
                  ),
                ),
                child: Text(
                  '$condition',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AsakaoStyle.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                  color: selected ? AsakaoStyle.coralInk : AsakaoStyle.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
