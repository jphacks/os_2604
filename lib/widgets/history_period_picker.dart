import 'package:flutter/material.dart';

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
    required this.availableMonths,
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
  final Set<int> availableMonths;
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
    panel: AsakaoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('年', style: AsakaoStyle.caption),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final y in years)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      key: ValueKey('history-year-$y'),
                      style: TextButton.styleFrom(
                        backgroundColor: y == year
                            ? Colors.white
                            : AsakaoStyle.neutralBackground,
                        foregroundColor: AsakaoStyle.ink,
                        side: BorderSide(
                          color: y == year
                              ? AsakaoStyle.border
                              : Colors.transparent,
                        ),
                        minimumSize: const Size(120, 44),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => onYear(y),
                      child: Text('$y年'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('月', style: AsakaoStyle.caption),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? 3
                  : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var m = 1; m <= 12; m++)
                    SizedBox(
                      width: width,
                      child: TextButton(
                        key: ValueKey('history-month-$m'),
                        style: TextButton.styleFrom(
                          backgroundColor: month == m
                              ? AsakaoStyle.coral
                              : availableMonths.contains(m)
                              ? Colors.white
                              : AsakaoStyle.neutralBackground,
                          foregroundColor: AsakaoStyle.ink,
                          disabledBackgroundColor:
                              AsakaoStyle.neutralBackground,
                          disabledForegroundColor: AsakaoStyle.muted.withValues(
                            alpha: 0.5,
                          ),
                          side: BorderSide(
                            color: availableMonths.contains(m) && month != m
                                ? AsakaoStyle.border
                                : Colors.transparent,
                          ),
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: availableMonths.contains(m)
                            ? () => onMonth(m)
                            : null,
                        child: Text('$m月'),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('history-whole-year'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AsakaoStyle.ink,
              side: const BorderSide(color: AsakaoStyle.border),
              minimumSize: const Size(44, 48),
            ),
            onPressed: onWholeYear,
            child: Text('$year年をすべて表示'),
          ),
        ],
      ),
    ),
  );
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
