import 'package:flutter/material.dart';

/// 任意の自己申告。値の保持・保存は呼び出し元が扱う。
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今日の体調（任意）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('1：よくない 〜 5：よい。入力せずに進むこともできます。'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var condition = 1; condition <= 5; condition++)
              ChoiceChip(
                label: Text('$condition'),
                tooltip: '体調 $condition / 5',
                selected: value == condition,
                onSelected: (selected) =>
                    onChanged(selected ? condition : null),
              ),
          ],
        ),
        Text(value == null ? '未選択' : '選択中：$value / 5'),
        TextButton(
          onPressed: value == null ? null : () => onChanged(null),
          child: const Text('選択を解除'),
        ),
      ],
    );
  }
}
