import 'package:flutter/material.dart';

import 'asakao_style.dart';

/// 設定の下位ページの枠。左上に「設定」へ戻るリンク、その下に大きな見出し。
/// [eyebrow] は見出しの上に出す小さな一言、[lead] は見出しの下の説明。
class AsakaoSubpage extends StatelessWidget {
  const AsakaoSubpage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.lead,
  });

  final String title;
  final String? eyebrow;
  final String? lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AsakaoStyle.background,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 120,
      leading: const Align(
        alignment: Alignment.centerLeft,
        child: _BackToSettings(),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(eyebrow!, style: AsakaoStyle.sectionLabel),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Semantics(
              header: true,
              child: Text(title, style: AsakaoStyle.title),
            ),
          ),
          if (lead != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                lead!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: Color(0xFF4A3F39),
                ),
              ),
            ),
          ...children,
        ],
      ),
    ),
  );
}

class _BackToSettings extends StatelessWidget {
  const _BackToSettings();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '設定に戻る',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('subpage-back'),
      onTap: () => Navigator.of(context).maybePop(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new, size: 16, color: AsakaoStyle.link),
              SizedBox(width: 4),
              Text(
                '設定',
                style: TextStyle(fontSize: 17, color: AsakaoStyle.link),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
