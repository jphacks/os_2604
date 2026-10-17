import 'package:flutter/material.dart';

/// 任意の外部体温。保存側は [onValidityChanged] がfalseの間は保存しないこと。
/// 不正入力では古い親値を残さないよう [onChanged] にnullも通知する。
class ManualTemperatureInput extends StatefulWidget {
  const ManualTemperatureInput({
    super.key,
    required this.value,
    this.enabled = true,
    required this.onChanged,
    required this.onValidityChanged,
  }) : assert(
         value == null ||
             (value > double.negativeInfinity && value < double.infinity),
       );

  final bool enabled;
  final double? value;
  final ValueChanged<double?> onChanged;
  final ValueChanged<bool> onValidityChanged;

  @override
  State<ManualTemperatureInput> createState() => _ManualTemperatureInputState();
}

class _ManualTemperatureInputState extends State<ManualTemperatureInput> {
  late final TextEditingController _controller;
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  double? _lastReportedValue;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _lastReportedValue = widget.value;
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant ManualTemperatureInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親が通知値を返しただけなら、入力中の文字列を保持する。
    if (widget.value != _lastReportedValue) {
      _lastReportedValue = widget.value;
      final revision = ++_revision;
      final currentValue = widget.value;
      final text = currentValue?.toString() ?? '';
      _controller.text = text;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            revision != _revision ||
            widget.value != currentValue ||
            _controller.text != text) {
          return;
        }
        _fieldKey.currentState?.validate();
        widget.onValidityChanged(_isValid(text));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim());

  bool _isValid(String text) =>
      text.trim().isEmpty ||
      ((_parse(text)?.isFinite ?? false) && _parse(text)! > 0);

  void _report(String text) {
    _revision++;
    final valid = _isValid(text);
    final next = valid ? _parse(text) : null;
    _lastReportedValue = next;
    widget.onValidityChanged(valid);
    widget.onChanged(next);
    _fieldKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('体温（任意）', style: Theme.of(context).textTheme.titleMedium),
        const Text('外部の体温計による手入力'),
        const Text('カメラでは体温を測定しません'),
        const SizedBox(height: 8),
        TextFormField(
          key: _fieldKey,
          enabled: widget.enabled,
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(labelText: '体温', suffixText: '℃'),
          validator: (text) =>
              _isValid(text ?? '') ? null : '0より大きい有限の数値を入力してください',
          onChanged: _report,
          onFieldSubmitted: _report,
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: widget.enabled
                  ? () => _report(_controller.text)
                  : null,
              child: const Text('入力を確認'),
            ),
            TextButton(
              onPressed: !widget.enabled
                  ? null
                  : () {
                      _controller.clear();
                      _report('');
                    },
              child: const Text('入力を消す'),
            ),
          ],
        ),
      ],
    );
  }
}
