import 'package:flutter/material.dart';

import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// 任意の外部体温（手入力）。34.0〜42.0 ℃、または空欄を有効とする。
/// 保存側は [onValidityChanged] がfalseの間は保存しないこと。
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

  /// 入力できる体温の範囲（℃）。
  static const minCelsius = 34.0;
  static const maxCelsius = 42.0;
  static const rangeMessage = '34.0〜42.0℃の範囲で入力してください。空欄のままでも進めます。';

  final bool enabled;
  final double? value;
  final ValueChanged<double?> onChanged;
  final ValueChanged<bool> onValidityChanged;

  @override
  State<ManualTemperatureInput> createState() => _ManualTemperatureInputState();
}

class _ManualTemperatureInputState extends State<ManualTemperatureInput> {
  late final TextEditingController _controller;
  double? _lastReportedValue;
  int _revision = 0;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _lastReportedValue = widget.value;
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
    _invalid = !_isValid(_controller.text);
    if (_invalid) {
      // 保存済みの範囲外の値を開いた場合、親へ保存不可を通知する。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _invalid) widget.onValidityChanged(false);
      });
    }
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
        final valid = _isValid(text);
        setState(() => _invalid = !valid);
        widget.onValidityChanged(valid);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim());

  bool _isValid(String text) {
    if (text.trim().isEmpty) return true;
    final v = _parse(text);
    return v != null &&
        v.isFinite &&
        v >= ManualTemperatureInput.minCelsius &&
        v <= ManualTemperatureInput.maxCelsius;
  }

  void _report(String text) {
    _revision++;
    final valid = _isValid(text);
    final next = valid ? _parse(text) : null;
    _lastReportedValue = next;
    setState(() => _invalid = !valid);
    widget.onValidityChanged(valid);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _invalid ? AsakaoStyle.destructive : AsakaoStyle.border;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: _invalid ? 2 : 1.5),
    );
    return AsakaoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '体温',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AsakaoStyle.ink,
                  ),
                ),
              ),
              const Text('任意', style: AsakaoStyle.caption),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AsakaoStyle.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: '36.4',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: border(borderColor),
                    focusedBorder: border(
                      _invalid ? AsakaoStyle.destructive : AsakaoStyle.coral,
                    ),
                    disabledBorder: border(AsakaoStyle.border),
                  ),
                  onChanged: _report,
                  onFieldSubmitted: _report,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '℃',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AsakaoStyle.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_invalid)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AsakaoStyle.destructive,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ManualTemperatureInput.rangeMessage,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AsakaoStyle.destructive,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            const Text('手持ちの体温計で測った値を入力します。', style: AsakaoStyle.caption),
            const Text('カメラでは体温を測定しません。', style: AsakaoStyle.caption),
          ],
        ],
      ),
    );
  }
}
