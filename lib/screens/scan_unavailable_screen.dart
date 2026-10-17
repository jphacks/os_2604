import 'package:flutter/material.dart';

/// 計測サービスが未接続の場合だけ表示する案内。
class ScanUnavailableScreen extends StatelessWidget {
  const ScanUnavailableScreen({super.key, required this.onBackToHome});

  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チェックの準備中')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '計測サービスの接続待ちです',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text('カメラ・計測サービスが未接続のため、現在はチェックを開始できません。'),
              const SizedBox(height: 16),
              const Text('この画面では撮影・計測・記録の保存は行いません。'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onBackToHome,
                child: const Text('ホームへ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
