import 'package:flutter/material.dart';

/// サービス接続前のホーム。記録の有無を推測して表示しない。
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onStartCheck,
    required this.onOpenHistory,
    required this.onOpenSettings,
    this.onShowExplanation,
  });

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
              const Text('記録を確認できません（履歴未接続）。'),
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
