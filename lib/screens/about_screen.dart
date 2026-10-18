import 'package:flutter/material.dart';

import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// このアプリについて。説明・免責事項・データの扱い。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _disclaimers = [
    'あさかおは医療機器ではなく、病気の診断・治療・予防を目的としていません。',
    '推定値は撮影環境などで変わる目安で、正確さは保証されません。',
    '体調に不安があるときは、医療機関に相談してください。',
    '急な体調の悪化など緊急のときは、ためらわず119番に連絡してください。',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('このアプリについて')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              AsakaoMascot(size: 64),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('あさかお', style: AsakaoStyle.title),
                    Text('毎朝15秒のセルフチェック', style: AsakaoStyle.caption),
                  ],
                ),
              ),
            ],
          ),
          const AsakaoSectionLabel('このアプリについて'),
          const AsakaoCard(
            child: Text(
              'あさかおは、毎朝15秒カメラに顔を向けて、その日の体調をかんたんに記録するためのアプリです。'
              '毎日の記録を見返して体調の変化を確認できます。',
              style: AsakaoStyle.body,
            ),
          ),
          const AsakaoSectionLabel('免責事項'),
          AsakaoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final text in _disclaimers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 9, right: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AsakaoStyle.coral,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox.square(dimension: 6),
                          ),
                        ),
                        Expanded(child: Text(text, style: AsakaoStyle.body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const AsakaoSectionLabel('データの扱い'),
          const AsakaoCard(
            child: Text(
              '撮影した映像は解析後すぐに破棄し、保存しません。記録はこの端末の中だけに保存されます。',
              style: AsakaoStyle.body,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '© 2026 JPHacks os_04 CYPR',
              textAlign: TextAlign.center,
              style: AsakaoStyle.caption,
            ),
          ),
        ],
      ),
    ),
  );
}
