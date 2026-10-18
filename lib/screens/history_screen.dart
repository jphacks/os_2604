import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_transitions.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_store.dart';
import '../ui/asakao_flower.dart';
import '../ui/asakao_record_widgets.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import '../widgets/history_trend_view.dart';
import '../widgets/history_period_picker.dart';

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
  late int _year = widget.now().toLocal().year;
  late int? _month = widget.now().toLocal().month;
  bool _periodExpanded = false;

  bool _inPeriod(HealthCheckResult r) {
    final at = r.measuredAt.toLocal();
    return at.year == _year && (_month == null || at.month == _month);
  }

  DateTimeRange get _period => DateTimeRange(
    start: DateTime(_year, _month ?? 1),
    end: DateTime(_year, _month == null ? 13 : _month! + 1, 0),
  );

  Widget _periodPicker(List<HealthCheckResult> records, int count) {
    final years = {
      widget.now().toLocal().year,
      _year,
      for (final r in records) r.measuredAt.toLocal().year,
    }.toList()..sort((a, b) => b.compareTo(a));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: HistoryPeriodPicker(
        year: _year,
        month: _month,
        expanded: _periodExpanded,
        years: years,
        count: count,
        availableMonths: {
          for (final r in records)
            if (r.measuredAt.toLocal().year == _year)
              r.measuredAt.toLocal().month,
        },
        onToggle: () => setState(() => _periodExpanded = !_periodExpanded),
        onYear: (year) => setState(() {
          _year = year;
          _month = null;
        }),
        onMonth: (month) => setState(() {
          _month = month;
          _periodExpanded = false;
        }),
        onWholeYear: () => setState(() {
          _month = null;
          _periodExpanded = false;
        }),
      ),
    );
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

  Widget _surface(Widget child, {bool fullBleed = false}) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: fullBleed
        ? const Border(
            top: BorderSide(color: AsakaoStyle.border),
            bottom: BorderSide(color: AsakaoStyle.border),
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

  Widget _list(List<HealthCheckResult> records, {bool noRecords = false}) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          children: [
            Text(
              noRecords ? 'まだ記録がありません' : 'この期間の記録はありません',
              style: const TextStyle(
                fontFamily: AsakaoStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AsakaoStyle.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '年月を変更するか、カメラから新しい記録をつけてください。',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.6, color: AsakaoStyle.muted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < records.length; index++) ...[
          if (_month == null &&
              (index == 0 ||
                  records[index - 1].measuredAt.toLocal().month !=
                      records[index].measuredAt.toLocal().month ||
                  records[index - 1].measuredAt.toLocal().year !=
                      records[index].measuredAt.toLocal().year))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${records[index].measuredAt.toLocal().year}年${records[index].measuredAt.toLocal().month}月',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AsakaoStyle.muted,
                ),
              ),
            ),
          _record(records[index]),
          const SizedBox(height: 8),
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
    bool bloomed(DateTime day) => records.any(
      (r) =>
          r.quality == MeasurementQuality.good &&
          _sameDay(r.measuredAt.toLocal(), day),
    );
    final latest = records
        .where(
          (r) =>
              r.quality == MeasurementQuality.good &&
              _sameDay(r.measuredAt.toLocal(), today),
        )
        .firstOrNull;
    final sunday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday % 7,
    );
    final days = List.generate(
      7,
      (i) => DateTime(sunday.year, sunday.month, sunday.day + i),
    );
    final done = [for (final d in days) !d.isAfter(today) && bloomed(d)];

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Expanded(
                    child: Text(
                      '今週咲いた花',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AsakaoStyle.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Semantics(
                        label:
                            '${days[i].month}月${days[i].day}日 ${done[i] ? '記録あり' : '記録なし'}',
                        excludeSemantics: true,
                        child: Column(
                          children: [
                            Text(
                              asakaoWeekdays[days[i].weekday - 1],
                              style: _sameDay(days[i], today)
                                  ? const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AsakaoStyle.todayAccent,
                                    )
                                  : const TextStyle(
                                      fontSize: 12,
                                      color: AsakaoStyle.muted,
                                    ),
                            ),
                            const SizedBox(height: 5),
                            if (_sameDay(days[i], today))
                              // 計測から戻って履歴が見えたときに、今日のつぼみが咲く。
                              AsakaoTodayBloom(
                                bloomed: done[i],
                                visible:
                                    ModalRoute.isCurrentOf(context) ?? true,
                              )
                            else
                              AsakaoDayFlower(
                                state: done[i]
                                    ? AsakaoFlowerState.bloomed
                                    : AsakaoFlowerState.bud,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      fullBleed: true,
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

  Widget _record(HealthCheckResult record) {
    final at = record.measuredAt.toLocal();
    final cond = record.selfCondition;
    // 文字が大きいときは日付の列を省き、横幅を本文に回す。
    final compact = MediaQuery.textScalerOf(context).scale(22) > 30;
    return _surface(
      InkWell(
        key: ValueKey('history-row-${record.id}'),
        onTap: () => _open(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      const SizedBox(height: 4),
                      Text(formatClock(at), style: AsakaoStyle.caption),
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
                        if (compact)
                          Text(formatClock(at), style: AsakaoStyle.caption),
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
    );
  }

  Widget _viewToggle() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AsakaoStyle.neutralBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final (label, graph) in const [('リスト', false), ('グラフ', true)])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _graph == graph,
                  excludeSemantics: true,
                  label: label,
                  onTap: () => _showView(graph: graph),
                  child: Material(
                    color: _graph == graph ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showView(graph: graph),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AsakaoStyle.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
          final records = [...data]
            ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
          final filtered = records.where(_inPeriod).toList();
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
                          children: [
                            _baselineCard(records),
                            _viewToggle(),
                            _periodPicker(records, filtered.length),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                // リスト ↔ グラフはスイッチより下だけを入れ替える。
                // グラフは右から、リストは左から入る（push の向き）。
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: AppTransitions.fadeDuration,
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
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _graph
                        ? Padding(
                            key: const ValueKey('history-graph'),
                            padding: const EdgeInsets.only(top: 12),
                            child: HistoryTrendView(
                              records: filtered,
                              now: widget.now,
                              period: _period,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('history-list'),
                            child: _list(filtered, noRecords: records.isEmpty),
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
