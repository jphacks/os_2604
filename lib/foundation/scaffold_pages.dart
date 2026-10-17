import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';

/// Temporary development launcher, replaced by agent 2's production screens.
class FoundationHomePage extends StatelessWidget {
  const FoundationHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('15秒健康チェック')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('開発用の画面骨格'),
          const SizedBox(height: 12),
          const Text('画面遷移の確認用です。撮影・計測・保存はまだ利用できません。'),
          const SizedBox(height: 24),
          for (final entry in AppRoutes.destinations.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(entry.key),
            ),
        ],
      ),
    );
  }
}

class FoundationPlaceholderPage extends StatelessWidget {
  const FoundationPlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text('未実装の画面です。今後、担当機能を接続します。'),
      ),
    );
  }
}
