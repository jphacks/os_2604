import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/db/health_record_store.dart';
import 'result_screen.dart';

/// サービス接続前のホーム。記録の有無を推測して表示しない。
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onStartCheck,
    required this.onOpenHistory,
    required this.onOpenSettings,
    this.onShowExplanation,
    this.recordStore,
  });

  final VoidCallback onStartCheck;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;
  final VoidCallback? onShowExplanation;
  final HealthRecordStore? recordStore;

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
              if (recordStore case final store?)
                _HomeRecords(store: store)
              else ...[
                const Text('記録を確認できません（履歴未接続）。'),
                const SizedBox(height: 16),
                const Text('現在、実際の計測・保存サービスは未接続です。チェック開始から接続状況を確認できます。'),
              ],
              const SizedBox(height: 24),
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
}

class _HomeRecords extends StatefulWidget {
  const _HomeRecords({required this.store});
  final HealthRecordStore store;

  @override
  State<_HomeRecords> createState() => _HomeRecordsState();
}

class _HomeRecordsState extends State<_HomeRecords> {
  late Stream<List<HealthCheckResult>> _records = widget.store.watchAll();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<HealthCheckResult>>(
    stream: _records,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(() => _records = widget.store.watchAll()),
          child: const Text('記録を読み込めません。再試行'),
        );
      }
      final records = snapshot.data;
      if (records == null) return const Text('記録を読み込み中…');
      if (records.isEmpty) return const Text('まだ測定記録はありません。');
      final previous = records.first;
      final date = previous.measuredAt.toLocal();
      final now = DateTime.now();
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      return Text(
        '${isToday ? '本日のチェックは完了しています' : '本日はまだチェックしていません'}\n前回：${formatRecordDate(date)} / 品質：良好',
      );
    },
  );
}
