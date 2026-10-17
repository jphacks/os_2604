import 'package:flutter/material.dart';

import '../services/db/health_record_repository.dart';

/// 設定。現時点では健康記録の全削除のみ提供する。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final HealthRecordRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _running = false;
  String? _message;

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての健康記録を削除しますか？'),
        content: const Text('保存されている記録がすべて消え、元に戻せません。初回の説明の確認状態は残ります。'),
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
    if (ok != true || !mounted) return;
    setState(() {
      _running = true;
      _message = null;
    });
    String message;
    try {
      await widget.repository.deleteAll();
      message = 'すべての健康記録を削除しました';
    } catch (_) {
      message = '削除できませんでした（記録は削除されていません）';
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('通知設定は今後追加予定です'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _running ? null : _deleteAll,
              child: const Text('すべての健康記録を削除'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 24),
            const Text('このアプリは診断目的ではありません', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
