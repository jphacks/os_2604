import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../navigation/app_routes.dart';
import '../services/analysis/history_baseline.dart';
import '../ui/asakao_style.dart';
import '../services/db/health_record_store.dart';
import 'result_screen.dart';

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
  bool _deleting = false;

  Future<void> _delete(String id) async {
    if (_deleting) return;
    final confirmed = await confirmRecordDeletion(context, all: false);
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.store.deleteOne(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除できませんでした。再試行してください。')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _quality(HealthCheckResult r) => switch (r.quality) {
    MeasurementQuality.good => '良好',
    MeasurementQuality.poor => '不十分',
    MeasurementQuality.interrupted => '中断',
  };

  Widget _surface(Widget child) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AsakaoStyle.border),
    ),
    child: child,
  );

  void _open(HealthCheckResult record) =>
      Navigator.of(context).pushNamed(AppRoutes.result, arguments: record.id);

  Widget _today(List<HealthCheckResult> records) {
    final today = widget.now().toLocal();
    final valid = records.where(
      (r) =>
          r.quality == MeasurementQuality.good &&
          _sameDay(r.measuredAt.toLocal(), today),
    );
    final latest = valid.firstOrNull;
    return _surface(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                latest == null
                    ? Icons.local_florist_outlined
                    : Icons.local_florist,
                size: 40,
                color: latest == null ? AsakaoStyle.muted : AsakaoStyle.coral,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日 · ${today.month}月${today.day}日（${_weekdays[today.weekday - 1]}）',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AsakaoStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    latest == null ? '今日はまだチェックしていません' : '今日のチェック完了',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AsakaoStyle.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (latest != null)
                    TextButton(
                      onPressed: () => _open(latest),
                      child: const Text('今日の記録を見る'),
                    )
                  else if (widget.onStartCheck != null)
                    TextButton(
                      onPressed: widget.onStartCheck,
                      child: const Text('チェック開始'),
                    )
                  else
                    const Text(
                      'カメラから15秒で記録できます',
                      style: TextStyle(fontSize: 12, color: AsakaoStyle.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _week(List<HealthCheckResult> records) {
    final now = widget.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday % 7,
    );
    final days = List.generate(
      7,
      (i) => DateTime(sunday.year, sunday.month, sunday.day + i),
    );
    final done = days
        .map(
          (day) =>
              !day.isAfter(today) &&
              records.any(
                (r) =>
                    r.quality == MeasurementQuality.good &&
                    _sameDay(r.measuredAt.toLocal(), day),
              ),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '今週咲いた花',
                  style: TextStyle(fontSize: 13, color: AsakaoStyle.muted),
                ),
              ),
              Text(
                '${done.where((v) => v).length}輪',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AsakaoStyle.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
                          _weekdays[days[i].weekday - 1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AsakaoStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          done[i] ? Icons.local_florist : Icons.eco_outlined,
                          size: 26,
                          color: done[i]
                              ? AsakaoStyle.coral
                              : AsakaoStyle.border,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${days[i].day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _sameDay(days[i], today)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: AsakaoStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _record(HealthCheckResult record) {
    final at = record.measuredAt.toLocal();
    final good = record.quality == MeasurementQuality.good;
    return _surface(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: MediaQuery.textScalerOf(context).scale(22) > 30
            ? null
            : SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '${at.day}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AsakaoStyle.ink,
                    ),
                  ),
                ),
              ),
        title: Text(
          formatRecordDate(at),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AsakaoStyle.ink,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '品質：${_quality(record)} / 体調：${record.selfCondition == null ? '未入力' : '${record.selfCondition} / 5'}',
                style: TextStyle(
                  fontSize: 12,
                  color: good ? AsakaoStyle.goodInk : AsakaoStyle.poorInk,
                ),
              ),
              if (record.reportText != null) ...[
                const SizedBox(height: 4),
                Text(
                  record.reportText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AsakaoStyle.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        onTap: _deleting ? null : () => _open(record),
        trailing: IconButton(
          tooltip: 'この記録を削除',
          onPressed: _deleting ? null : () => _delete(record.id),
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: AsakaoStyle.muted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AsakaoStyle.background,
    appBar: AppBar(
      title: const Text(
        '履歴',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AsakaoStyle.ink,
        ),
      ),
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
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _today(records),
                      _week(records),
                      _baselineCard(records),
                    ],
                  ),
                ),
              ),
              if (records.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_florist_outlined,
                          size: 44,
                          color: AsakaoStyle.coral,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'まだ記録がありません',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AsakaoStyle.ink,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '測定記録はまだありません。',
                          style: TextStyle(color: AsakaoStyle.muted),
                        ),
                        Text(
                          '最初のチェックのあと、ここに毎朝の記録が並びます。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.6,
                            color: AsakaoStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final r = records[index];
                    final date = r.measuredAt.toLocal();
                    final previous = index == 0
                        ? null
                        : records[index - 1].measuredAt.toLocal();
                    final monthStart =
                        previous == null ||
                        previous.year != date.year ||
                        previous.month != date.month;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (monthStart)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '${date.year}年${date.month}月',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AsakaoStyle.muted,
                              ),
                            ),
                          ),
                        _record(r),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
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
