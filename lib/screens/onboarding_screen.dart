import 'package:flutter/material.dart';

/// 初回のデータ利用説明。権限要求と設定の保存は呼び出し元が扱う。
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.onContinue,
    this.isSaving = false,
    this.saveError,
  });

  final VoidCallback onContinue;
  final bool isSaving;
  final String? saveError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('はじめに')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '毎朝15秒、自分の変化を振り返る',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                '顔の位置と明るさを確認してから15秒間撮影します。日々の記録を通じて、過去の自分との変化を振り返ります。',
              ),
              const SizedBox(height: 24),
              const Text('データは端末内で処理します。画像・動画は保存せず、必要な集計値や入力した体調を端末内に記録します。'),
              const SizedBox(height: 16),
              const Text('このアプリは診断目的ではありません。病気の診断や治療判断には使用できません。'),
              const SizedBox(height: 16),
              const Text(
                '通常モードでは心拍・顔色の実験処理は行いません。撮影前に研究モードを選ぶと試験的に推定します。精度の保証はなく、健康状態の判定には使用できません。',
              ),
              const SizedBox(height: 16),
              const Text('撮影にはカメラ権限が必要です。この説明の後、カメラを使う際に許可を確認します。'),
              const SizedBox(height: 32),
              if (saveError != null) ...[
                Text(
                  saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: isSaving ? null : onContinue,
                child: Text(isSaving ? '保存中…' : '説明を確認して次へ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
