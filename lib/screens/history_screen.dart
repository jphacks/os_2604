import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../navigation/app_routes.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_store.dart';
import '../ui/asakao_flower.dart';
import '../ui/asakao_record_widgets.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import '../widgets/history_trend_view.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.store,
    this.now = DateTime.now,
    this.embedded = false,
    this.onStartCheck,
  });
  final VoidCallback? onStartCheck;
  final bool embedded;
  final HealthRecordStore store;

  /// 基準値の期間（今日を除く直近7日）の起点。テストでは固定時刻を渡す。
  final DateTime Function() now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Stream<List<HealthCheckResult>> _records = widget.store.watchAll();
  bool _graph = false;

  /// 記録がなくてもさかのぼれる週の数（今週を含めて約1年）。
  static const _minWeeks = 53;

  /// スイッチのつまみと下の画面は同じ速さで動かす。
  static const _viewSwitchDuration = Duration(milliseconds: 360);

  /// 左スワイプで削除済みの記録。
  final _removed = <String>{};

  /// 「咲いた花」の週。0 = 今週、1 = 先週…。
  int _weekPage = 0;
  final _weekPages = PageController();

  @override
  void dispose() {
    _weekPages.dispose();
    super.dispose();
  }

  Widget _baselineCard(List<HealthCheckResult> records) {
    final b = calculateHistoryBaseline([
      for (final r in records)
        (
          measuredAt: r.measuredAt,
          isValid: r.quality == MeasurementQuality.good,
          selfCondition: r.selfCondition,
        ),
    ], referenceDate: widget.now());
    final text = b.selfConditionMedian != null
        ? '直近7日間（今日を除く）の体調の中央値：${b.selfConditionMedian} / 5（有効記録 ${b.validRecordCount}件）'
        : b.validRecordCount < 3
        ? '基準値蓄積中（有効記録 ${b.validRecordCount}/3件）'
        : '基準値蓄積中（体調の記録 ${b.selfConditionCount}/3件）';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AsakaoStyle.muted,
          height: 1.5,
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _surface(Widget child, {bool fullBleed = false, bool top = true}) =>
      Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: fullBleed
            ? Border(
                top: top
                    ? const BorderSide(color: AsakaoStyle.border)
                    : BorderSide.none,
                bottom: const BorderSide(color: AsakaoStyle.border),
              )
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AsakaoStyle.border),
              ),
        child: child,
      );

  /// 5-1 ↔ 5-4。スイッチより下だけを入れ替える。
  void _showView({required bool graph}) {
    if (graph != _graph) setState(() => _graph = graph);
  }

  Widget _list(List<HealthCheckResult> records) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          children: [
            Text(
              'まだ記録がありません',
              style: TextStyle(
                fontFamily: AsakaoStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AsakaoStyle.ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '最初のチェックのあと、ここに毎朝の記録が並びます。',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6, color: AsakaoStyle.muted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < records.length; index++) ...[
          if (index == 0 ||
              records[index - 1].measuredAt.toLocal().month !=
                  records[index].measuredAt.toLocal().month ||
              records[index - 1].measuredAt.toLocal().year !=
                  records[index].measuredAt.toLocal().year)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${records[index].measuredAt.toLocal().year}年${records[index].measuredAt.toLocal().month}月',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AsakaoStyle.muted,
                ),
              ),
            ),
          // 行は画面の左右いっぱいに、すき間なく並べる（上の線は月の最初の行だけ）。
          _swipeToDelete(
            records[index],
            first:
                index == 0 ||
                records[index - 1].measuredAt.toLocal().month !=
                    records[index].measuredAt.toLocal().month ||
                records[index - 1].measuredAt.toLocal().year !=
                    records[index].measuredAt.toLocal().year,
          ),
        ],
      ],
    );
  }

  void _open(HealthCheckResult record) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.historyDetail, arguments: record.id);

  /// 5-1 / 5-1'。今日の状態と「今週咲いた花」を1枚のカードにまとめる。
  Widget _todayCard(List<HealthCheckResult> records) {
    final now = widget.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final latest = records
        .where(
          (r) =>
              r.quality == MeasurementQuality.good &&
              _sameDay(r.measuredAt.toLocal(), today),
        )
        .firstOrNull;
    final summary = Row(
      children: [
        // 5-1' → 5-1。チェックが済むと、その場でしおれた花が咲く。
        _bloomSwitch(
          SizedBox(
            key: ValueKey(latest == null),
            width: 92,
            height: 88,
            child: AsakaoMascot(
              mood: latest == null
                  ? AsakaoMascotMood.wilted
                  : AsakaoMascotMood.happy,
              size: 88,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                latest == null
                    ? '今日 · ${today.month}月${today.day}日（${asakaoWeekdays[today.weekday - 1]}）'
                    : '今日 · ${formatClock(latest.measuredAt.toLocal())} に記録',
                style: const TextStyle(fontSize: 12, color: AsakaoStyle.muted),
              ),
              const SizedBox(height: 2),
              Text(
                latest == null ? '今日はまだチェックしていません' : '今日のチェック完了',
                style: const TextStyle(
                  fontFamily: AsakaoStyle.displayFont,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AsakaoStyle.ink,
                ),
              ),
              const SizedBox(height: 4),
              if (latest == null)
                const Text(
                  '下のカメラから15秒で記録できます',
                  style: TextStyle(fontSize: 13, color: AsakaoStyle.ink),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AsakaoQualityChip(latest.quality),
                ),
            ],
          ),
        ),
        if (latest != null)
          const Icon(Icons.chevron_right, size: 22, color: AsakaoStyle.muted),
      ],
    );

    return _surface(
      Padding(
        // 中央の区切り線はフレームまで引くので、左右の余白は中身ごとに付ける。
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: latest == null
                  ? summary
                  : InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _open(latest),
                      child: summary,
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AsakaoStyle.border,
              ),
            ),
            _weekFlowers(records, today),
          ],
        ),
      ),
      fullBleed: true,
    );
  }

  /// 「今週咲いた花」。左右にスワイプ（または矢印）で過去の週へさかのぼれる。
  /// 日付を押すと、その日の記録（同じ日に複数あれば最新）を開く。
  Widget _weekFlowers(List<HealthCheckResult> records, DateTime today) {
    DateTime sundayOf(DateTime d) =>
        DateTime(d.year, d.month, d.day - d.weekday % 7);
    final thisSunday = sundayOf(today);
    // アプリを入れる前や記録がない週も、つぼみのまま1年前までさかのぼれる。
    // それより古い記録があれば、その週まで。
    final oldest = records.isEmpty ? today : records.last.measuredAt.toLocal();
    final weeks = math.max(
      _minWeeks,
      (thisSunday.difference(sundayOf(oldest)).inDays / 7).round() + 1,
    );
    final page = _weekPage.clamp(0, weeks - 1);
    final shownSunday = DateTime(
      thisSunday.year,
      thisSunday.month,
      thisSunday.day - 7 * page,
    );
    final shownSaturday = DateTime(
      shownSunday.year,
      shownSunday.month,
      shownSunday.day + 6,
    );
    final title = switch (page) {
      0 => '今週咲いた花',
      1 => '先週咲いた花',
      _ =>
        '${shownSunday.month}月${shownSunday.day}日〜${shownSaturday.month}月${shownSaturday.day}日に咲いた花',
    };

    void goTo(int target) => _weekPages.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );

    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 32),
          iconSize: 20,
          color: AsakaoStyle.muted,
          disabledColor: AsakaoStyle.disabled,
          icon: Icon(icon),
        );

    Widget weekRow(int index) {
      final sunday = DateTime(
        thisSunday.year,
        thisSunday.month,
        thisSunday.day - 7 * index,
      );
      return Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _dayCell(records, today, sunday.add(Duration(days: i))),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 見出しの上でも、左右になぞると週を切り替えられる。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v > 50 && page < weeks - 1) goTo(page + 1);
            if (v < -50 && page > 0) goTo(page - 1);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 22, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    key: const ValueKey('week-title'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AsakaoStyle.ink,
                    ),
                  ),
                ),
                arrow(
                  Icons.chevron_left,
                  '前の週',
                  page < weeks - 1 ? () => goTo(page + 1) : null,
                ),
                arrow(
                  Icons.chevron_right,
                  '次の週',
                  page > 0 ? () => goTo(page - 1) : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          // 曜日と日付（行の高さ 1.3、拡大設定に合わせる）＋すき間 4＋花 30px。
          height:
              MediaQuery.textScalerOf(context).scale(12 * 1.3 + 11 * 1.3) +
              4 +
              30 +
              2,
          // reverse：右へスワイプすると前の週（左側）が出てくる。
          child: PageView.builder(
            controller: _weekPages,
            reverse: true,
            itemCount: weeks,
            onPageChanged: (p) => setState(() => _weekPage = p),
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: weekRow(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCell(
    List<HealthCheckResult> records,
    DateTime today,
    DateTime day,
  ) {
    final isToday = _sameDay(day, today);
    final future = day.isAfter(today);
    final ofDay = future
        ? const <HealthCheckResult>[]
        : records.where((r) => _sameDay(r.measuredAt.toLocal(), day)).toList();
    final bloomed = ofDay.any((r) => r.quality == MeasurementQuality.good);
    final target = ofDay.firstOrNull; // records は新しい順
    return Semantics(
      button: target != null,
      label: '${day.month}月${day.day}日 ${bloomed ? '記録あり' : '記録なし'}',
      excludeSemantics: true,
      onTap: target == null ? null : () => _open(target),
      child: GestureDetector(
        key: ValueKey('week-day-${day.month}-${day.day}'),
        behavior: HitTestBehavior.opaque,
        onTap: target == null ? null : () => _open(target),
        child: Column(
          children: [
            Text(
              asakaoWeekdays[day.weekday - 1],
              maxLines: 1,
              softWrap: false,
              style: isToday
                  ? const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AsakaoStyle.todayAccent,
                    )
                  : const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AsakaoStyle.muted,
                    ),
            ),
            Text(
              '${day.day}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: isToday ? AsakaoStyle.todayAccent : AsakaoStyle.muted,
              ),
            ),
            const SizedBox(height: 4),
            if (isToday)
              // 計測から戻って履歴が見えたときに、今日のつぼみが咲く。
              AsakaoTodayBloom(
                bloomed: bloomed,
                visible: ModalRoute.isCurrentOf(context) ?? true,
              )
            else
              AsakaoDayFlower(
                state: bloomed
                    ? AsakaoFlowerState.bloomed
                    : AsakaoFlowerState.bud,
              ),
          ],
        ),
      ),
    );
  }

  /// つぼみ → 花の切り替え。少し弾ませて咲かせる。
  static Widget _bloomSwitch(Widget child) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 450),
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: child,
  );

  /// 行を左へスワイプすると削除。確認してから消し、失敗したら行を戻して知らせる。
  Widget _swipeToDelete(HealthCheckResult record, {required bool first}) =>
      Dismissible(
        key: ValueKey('history-dismiss-${record.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: AsakaoStyle.destructive,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '削除',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          if (!await confirmRecordDeletion(context, all: false)) return false;
          try {
            await widget.store.deleteOne(record.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('削除できませんでした。再試行してください。')),
              );
            }
            return false;
          }
        },
        onDismissed: (_) => setState(() => _removed.add(record.id)),
        child: _record(record, first: first),
      );

  Widget _record(HealthCheckResult record, {required bool first}) {
    final at = record.measuredAt.toLocal();
    final cond = record.selfCondition;
    // 文字が大きいときは日付の列を省き、横幅を本文に回す。
    final compact = MediaQuery.textScalerOf(context).scale(22) > 30;
    return _surface(
      InkWell(
        key: ValueKey('history-row-${record.id}'),
        onTap: () => _open(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              if (!compact)
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Text(
                        '${at.day}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AsakaoStyle.ink,
                        ),
                      ),
                      Text(
                        asakaoWeekdays[at.weekday - 1],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AsakaoStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!compact) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AsakaoQualityChip(record.quality),
                        Text(
                          formatClock(at),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AsakaoStyle.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.reportText ?? 'レポートは未作成です',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AsakaoStyle.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 数字がカードの縦中央に来るよう、上の「体調」と同じ高さを下にも空ける。
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('体調', style: AsakaoStyle.caption),
                  Text(
                    cond == null ? '未入力' : '$cond',
                    style: cond == null
                        ? const TextStyle(
                            fontSize: 12,
                            color: AsakaoStyle.muted,
                          )
                        : const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AsakaoStyle.ink,
                          ),
                  ),
                  const ExcludeSemantics(
                    child: Opacity(
                      opacity: 0,
                      child: Text('体調', style: AsakaoStyle.caption),
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: AsakaoStyle.muted,
              ),
            ],
          ),
        ),
      ),
      fullBleed: true,
      top: first,
    );
  }

  /// リスト／グラフのスイッチ。白いつまみが横にすべるだけで、押したときの色の変化は出さない。
  /// つまみを左右になぞっても切り替わる。
  Widget _viewToggle() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 50) _showView(graph: v > 0);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AsakaoStyle.neutralBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: _viewSwitchDuration,
              curve: Curves.easeInOutCubic,
              alignment: _graph ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (label, graph) in const [
                  ('リスト', false),
                  ('グラフ', true),
                ])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _graph == graph,
                      excludeSemantics: true,
                      label: label,
                      onTap: () => _showView(graph: graph),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showView(graph: graph),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: AsakaoStyle.bodyFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _graph == graph
                                  ? AsakaoStyle.ink
                                  : AsakaoStyle.muted,
                            ),
                            child: Text(label),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AsakaoStyle.background,
    appBar: AppBar(
      title: const Text('履歴', style: AsakaoStyle.tabTitle),
      backgroundColor: AsakaoStyle.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      automaticallyImplyLeading: !widget.embedded,
    ),
    body: SafeArea(
      top: false,
      child: StreamBuilder<List<HealthCheckResult>>(
        stream: _records,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _records = widget.store.watchAll()),
                child: const Text('履歴を読み込めません。再試行'),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          // スワイプで消した行は、DB の更新が届く前でもすぐ外す。
          final records = [...data.where((r) => !_removed.contains(r.id))]
            ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _todayCard(records),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_baselineCard(records), _viewToggle()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                // リスト ↔ グラフはスイッチより下だけを入れ替える。
                // グラフは右から、リストは左から入る（push の向き）。
                sliver: SliverToBoxAdapter(
                  // 出ていく画面と入ってくる画面が重ならないよう、前後で対称な曲線を使い、
                  // 2枚を横に並べたまま一緒に動かす（フェードはしない）。
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: _viewSwitchDuration,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position:
                            Tween(
                              begin: Offset(
                                child.key == const ValueKey('history-graph')
                                    ? 1
                                    : -1,
                                0,
                              ),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                      child: _graph
                          ? Padding(
                              key: const ValueKey('history-graph'),
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: HistoryTrendView(
                                records: records,
                                now: widget.now,
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('history-list'),
                              child: _list(records),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<bool> confirmRecordDeletion(
  BuildContext context, {
  required bool all,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(all ? 'すべての測定記録を削除しますか？' : 'この測定記録を削除しますか？'),
        content: const Text('削除すると元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ??
    false;

class RecordSettingsScreen extends StatefulWidget {
  const RecordSettingsScreen({super.key, required this.store});
  final HealthRecordStore store;

  @override
  State<RecordSettingsScreen> createState() => _RecordSettingsScreenState();
}

class _RecordSettingsScreenState extends State<RecordSettingsScreen> {
  bool _deleting = false;
  String? _message;

  Future<void> _deleteAll() async {
    if (_deleting) return;
    if (!await confirmRecordDeletion(context, all: true) || !mounted) return;
    setState(() {
      _deleting = true;
      _message = null;
    });
    try {
      await widget.store.deleteAll();
      if (mounted) setState(() => _message = '測定記録をすべて削除しました。');
    } catch (_) {
      if (mounted) setState(() => _message = '削除できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('設定')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('毎朝の通知は準備中です。ホームからチェックを開始してください。'),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _deleting ? null : _deleteAll,
          child: const Text('測定記録をすべて削除'),
        ),
        if (_message != null) Text(_message!),
      ],
    ),
  );
}
