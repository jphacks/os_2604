import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/db/health_record_repository.dart';

/// ホーム。本日の実施状態と前回結果は保存済みの記録から表示する。
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
    required this.onStartCheck,
    required this.onOpenHistory,
    required this.onOpenSettings,
    this.onShowExplanation,
  });

  final HealthRecordRepository repository;
  final DateTime Function() now;
  final VoidCallback onStartCheck;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;
  final VoidCallback? onShowExplanation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('15秒健康チェック')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '毎朝の自分を振り返る',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<HealthCheckResult>>(
                stream: repository.watchAll(),
                builder: (context, snapshot) => _status(snapshot),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onStartCheck,
                child: const Text('チェック開始'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onOpenHistory, child: const Text('履歴')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('設定'),
              ),
              if (onShowExplanation != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onShowExplanation,
                  child: const Text('アプリの説明'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(AsyncSnapshot<List<HealthCheckResult>> snapshot) {
    if (snapshot.hasError) return const Text('記録を読み込めませんでした。');
    final records = snapshot.data;
    if (records == null) return const Text('記録を読み込み中です…');
    final n = now();
    final todayDone = records.any(
      (r) =>
          r.quality == MeasurementQuality.good &&
          r.measuredAt.toLocal().year == n.year &&
          r.measuredAt.toLocal().month == n.month &&
          r.measuredAt.toLocal().day == n.day,
    );
    final latest = records.isEmpty ? null : records.first;
    String two(int v) => v.toString().padLeft(2, '0');
    final quality = switch (latest?.quality) {
      MeasurementQuality.good => '良好',
      MeasurementQuality.poor => '不十分',
      MeasurementQuality.interrupted => '中断',
      null => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(todayDone ? '本日は記録済み' : '本日はまだ記録がありません'),
        const SizedBox(height: 8),
        if (latest == null)
          const Text('前回結果：まだ記録がありません')
        else
          Text(
            '前回結果：${latest.measuredAt.year}/${two(latest.measuredAt.month)}/'
            '${two(latest.measuredAt.day)} ${two(latest.measuredAt.hour)}:'
            '${two(latest.measuredAt.minute)}　品質：$quality　'
            '体調：${latest.selfCondition == null ? '未測定' : '${latest.selfCondition} / 5'}',
          ),
      ],
    );
  }
}
