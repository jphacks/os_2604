import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../widgets/camera_tab_bar.dart';
import '../services/db/health_record_repository.dart';

/// ホーム。本日の実施状態と前回結果は保存済みの記録から表示する。
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
    this.showTabBar = true,
    required this.onStartCheck,
    required this.onOpenHistory,
    required this.onOpenSettings,
    this.onShowExplanation,
  });

  final bool showTabBar;
  final HealthRecordRepository repository;
  final DateTime Function() now;
  final VoidCallback onStartCheck;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;
  final VoidCallback? onShowExplanation;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEF9164);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDFC),
        surfaceTintColor: Colors.transparent,
        title: const Text('あさかお'),
        centerTitle: true,
      ),
      bottomNavigationBar: showTabBar
          ? CameraTabBar(onHistory: onOpenHistory, onSettings: onOpenSettings)
          : null,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEFE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 46,
                        color: Color(0xFFA34F28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '毎朝の自分を振り返る',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF392D28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '顔の位置と明るさを合わせて、15秒。\n今日の記録をはじめましょう。',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF382418),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: onStartCheck,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('チェック開始'),
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEDE5E0)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: StreamBuilder<List<HealthCheckResult>>(
                        stream: repository.watchAll(),
                        builder: (context, snapshot) => _status(snapshot),
                      ),
                    ),
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
