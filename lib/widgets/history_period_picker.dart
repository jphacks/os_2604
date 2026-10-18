import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// Year/month popover. Availability comes only from actual records.
class HistoryPeriodPicker extends StatelessWidget {
  const HistoryPeriodPicker({
    super.key,
    required this.year,
    required this.month,
    required this.expanded,
    required this.years,
    required this.monthsByYear,
    required this.count,
    required this.onToggle,
    required this.onYear,
    required this.onMonth,
    required this.onWholeYear,
  });
  final int year;
  final int? month;
  final bool expanded;
  final List<int> years;
  final Map<int, Set<int>> monthsByYear;
  final int count;
  final VoidCallback onToggle;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;
  final VoidCallback onWholeYear;

  @override
  Widget build(BuildContext context) => _AnchoredPeriodMenu(
    expanded: expanded,
    onDismiss: onToggle,
    header: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const ValueKey('history-period-toggle'),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AsakaoStyle.ink,
            side: const BorderSide(color: AsakaoStyle.border),
            shape: const StadiumBorder(),
            minimumSize: const Size(48, 44),
          ),
          onPressed: onToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                month == null ? '$year年すべて' : '$year年$month月',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
            ],
          ),
        ),
        Text(
          '$count件',
          key: const ValueKey('history-period-count'),
          style: AsakaoStyle.caption,
        ),
      ],
    ),
    panel: _PeriodWheels(
      year: year,
      month: month,
      years: years,
      monthsByYear: monthsByYear,
      onApply: (value) {
        onYear(value.year);
        value.month == null ? onWholeYear() : onMonth(value.month!);
      },
    ),
  );
}

class _PeriodWheels extends StatefulWidget {
  const _PeriodWheels({
    required this.year,
    required this.month,
    required this.years,
    required this.monthsByYear,
    required this.onApply,
  });
  final int year;
  final int? month;
  final List<int> years;
  final Map<int, Set<int>> monthsByYear;
  final ValueChanged<({int year, int? month})> onApply;
  @override
  State<_PeriodWheels> createState() => _PeriodWheelsState();
}

class _PeriodWheelsState extends State<_PeriodWheels> {
  late int _year = widget.year;
  late int? _month = widget.month;
  late final _yearScroll = FixedExtentScrollController(
    initialItem: widget.years.indexOf(_year),
  );
  late final _monthScroll = FixedExtentScrollController(
    initialItem: _month ?? 0,
  );
  bool _yearMoving = false;
  bool _monthMoving = false;
  @override
  void dispose() {
    _yearScroll.dispose();
    _monthScroll.dispose();
    super.dispose();
  }

  Widget _wheel({
    required String name,
    required FixedExtentScrollController controller,
    required List<Widget> children,
    required ValueChanged<int> onChanged,
  }) => Expanded(
    child: Column(
      children: [
        Text(name == 'year' ? '年' : '月', style: AsakaoStyle.caption),
        const SizedBox(height: 8),
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification ||
                notification is ScrollEndNotification) {
              setState(() {
                final moving = notification is ScrollStartNotification;
                name == 'year' ? _yearMoving = moving : _monthMoving = moving;
              });
            }
            return false;
          },
          child: SizedBox(
            height:
                MediaQuery.textScalerOf(context).scale(20).clamp(28, 44) * 4,
            child: CupertinoPicker(
              key: ValueKey('history-$name-wheel'),
              scrollController: controller,
              itemExtent:
                  MediaQuery.textScalerOf(context).scale(20).clamp(28, 44) + 16,
              onSelectedItemChanged: onChanged,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _label(String text, {bool available = true}) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: available
                ? AsakaoStyle.ink
                : AsakaoStyle.muted.withValues(alpha: 0.5),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final available =
        _month == null ||
        (widget.monthsByYear[_year]?.contains(_month) ?? false);
    return AsakaoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _wheel(
                name: 'year',
                controller: _yearScroll,
                children: [for (final year in widget.years) _label('$year年')],
                onChanged: (index) =>
                    setState(() => _year = widget.years[index]),
              ),
              const SizedBox(width: 12),
              _wheel(
                name: 'month',
                controller: _monthScroll,
                children: [
                  _label('すべて'),
                  for (var month = 1; month <= 12; month++)
                    _label(
                      '$month月',
                      available:
                          widget.monthsByYear[_year]?.contains(month) ?? false,
                    ),
                ],
                onChanged: (index) =>
                    setState(() => _month = index == 0 ? null : index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!available)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'この月の記録はありません',
                style: AsakaoStyle.caption,
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton(
            key: const ValueKey('history-period-apply'),
            onPressed: available && !_yearMoving && !_monthMoving
                ? () => widget.onApply((year: _year, month: _month))
                : null,
            child: const Text('表示する'),
          ),
        ],
      ),
    );
  }
}

/// The menu lives in an overlay, so opening it cannot move history rows.
class _AnchoredPeriodMenu extends StatefulWidget {
  const _AnchoredPeriodMenu({
    required this.expanded,
    required this.onDismiss,
    required this.header,
    required this.panel,
  });
  final bool expanded;
  final VoidCallback onDismiss;
  final Widget header;
  final Widget panel;
  @override
  State<_AnchoredPeriodMenu> createState() => _AnchoredPeriodMenuState();
}

class _AnchoredPeriodMenuState extends State<_AnchoredPeriodMenu> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _anchor = GlobalKey();

  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    widget.expanded ? _portal.show() : _portal.hide();
  });
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _AnchoredPeriodMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _sync();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.expanded,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && widget.expanded) widget.onDismiss();
    },
    child: LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          final media = MediaQuery.of(context);
          final below = media.size.height - media.padding.bottom - bottom - 16;
          final above = top - media.padding.top - 16;
          final upward = below < 160 && above > below;
          final available = upward ? above : below;
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ModalBarrier(
                    color: Colors.transparent,
                    dismissible: true,
                    onDismiss: widget.onDismiss,
                    semanticsLabel: '年月選択を閉じる',
                  ),
                ),
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: upward
                      ? Alignment.topLeft
                      : Alignment.bottomLeft,
                  followerAnchor: upward
                      ? Alignment.bottomLeft
                      : Alignment.topLeft,
                  offset: Offset(0, upward ? -10 : 10),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: available > 80 ? available : 80,
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: media.disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) => ClipRect(
                          child: Align(
                            alignment: upward
                                ? Alignment.bottomCenter
                                : Alignment.topCenter,
                            heightFactor: value,
                            child: Opacity(
                              opacity: 0.75 + 0.25 * value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  (upward ? 12 : -12) * (1 - value),
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                        child: Material(
                          key: const ValueKey('history-period-overlay'),
                          color: Colors.transparent,
                          elevation: 10,
                          shadowColor: AsakaoStyle.ink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(child: widget.panel),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: CompositedTransformTarget(
          key: _anchor,
          link: _link,
          child: widget.header,
        ),
      ),
    ),
  );
}
