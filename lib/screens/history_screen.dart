import 'dart:async';

import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../navigation/app_routes.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_repository.dart';

/// 保存済みの記録を新しい順に並べ、過去の自分の基準値と個別削除を提供する。
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  final HealthRecordRepository repository;

  /// 基準値の期間（今日を除く直近7日）の起点。テストでは固定時刻を渡す。
  final DateTime Function() now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  StreamSubscription<List<HealthCheckResult>>? _sub;
  List<HealthCheckResult>? _records;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.repository.watchAll().listen(
      (records) {
        setState(() {
          _records = records;
          _error = false;
        });
      },
      onError: (Object _) {
        if (mounted) setState(() => _error = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete(HealthCheckResult r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この記録を削除しますか？'),
        content: Text('${_fmt(r.measuredAt)} の記録を削除します。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    String message;
    try {
      await widget.repository.delete(r.id);
      message = '記録を削除しました';
    } catch (_) {
      message = '記録を削除できませんでした（削除されていません）';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final records = _records;
    if (_error) return const Center(child: Text('履歴を読み込めませんでした。'));
    if (records == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _baselineCard(records),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('まだ記録がありません')),
          ),
        for (var i = 0; i < records.length; i++) ...[
          if (i == 0 ||
              !_sameDay(records[i - 1].measuredAt, records[i].measuredAt))
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                _date(records[i].measuredAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          _tile(records[i]),
        ],
        const SizedBox(height: 16),
        const Text('このアプリは診断目的ではありません。', textAlign: TextAlign.center),
      ],
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
    final String text;
    if (b.selfConditionMedian != null) {
      text =
          '直近7日間（今日を除く）の体調の中央値：${b.selfConditionMedian} / 5'
          '（有効記録 ${b.validRecordCount}件）';
    } else if (b.validRecordCount < 3) {
      text = '基準値蓄積中（有効記録 ${b.validRecordCount}/3件）';
    } else {
      text = '基準値蓄積中（体調の記録 ${b.selfConditionCount}/3件）';
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }

  Widget _tile(HealthCheckResult r) {
    final t = r.bodyTemperatureC;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_fmt(r.measuredAt)),
      subtitle: Text(
        '品質：${_quality(r.quality)}　'
        '体調：${r.selfCondition == null ? '未測定' : '${r.selfCondition} / 5'}\n'
        '体温：${t == null ? '未測定' : '$t ℃（${_source(r.temperatureSource)}）'}',
      ),
      isThreeLine: true,
      onTap: () =>
          Navigator.of(context).pushNamed(AppRoutes.result, arguments: r.id),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: '${_fmt(r.measuredAt)} の記録を削除',
        onPressed: () => _confirmDelete(r),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';

  static String _fmt(DateTime d) =>
      '${_date(d)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _quality(MeasurementQuality q) => switch (q) {
    MeasurementQuality.good => '良好',
    MeasurementQuality.poor => '不十分',
    MeasurementQuality.interrupted => '中断',
  };

  static String _source(TemperatureSource s) => switch (s) {
    TemperatureSource.manual => '手入力',
    TemperatureSource.healthPlatform => 'ヘルスプラットフォーム',
    TemperatureSource.none => '出典なし',
  };
}
