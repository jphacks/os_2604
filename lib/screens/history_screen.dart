import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/db/health_record_store.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store});
  final HealthRecordStore store;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('履歴')),
    body: StreamBuilder<List<HealthCheckResult>>(
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
        final records = snapshot.data;
        if (records == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (records.isEmpty) return const Center(child: Text('測定記録はまだありません。'));
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return ListTile(
              title: Text(formatRecordDate(record.measuredAt)),
              subtitle: Text(
                '品質：良好 / 体調：${record.selfCondition == null ? '未入力' : '${record.selfCondition} / 5'}',
              ),
              onTap: _deleting
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ResultScreen(store: widget.store, result: record),
                      ),
                    ),
              trailing: IconButton(
                tooltip: 'この記録を削除',
                onPressed: _deleting ? null : () => _delete(record.id),
                icon: const Icon(Icons.delete_outline),
              ),
            );
          },
        );
      },
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
