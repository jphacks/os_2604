import 'package:flutter/material.dart';

import '../services/settings/scan_mode_store.dart';
import '../ui/asakao_subpage.dart';
import '../ui/asakao_widgets.dart';

/// 研究モードの切り替え。保存できたときだけ表示を切り替える（表示と実際をそろえる）。
class ResearchModePage extends StatefulWidget {
  const ResearchModePage({super.key, required this.store});

  final ScanModeStore store;

  @override
  State<ResearchModePage> createState() => _ResearchModePageState();
}

class _ResearchModePageState extends State<ResearchModePage> {
  bool? _research;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final research = await widget.store.loadResearchMode();
      if (mounted) {
        setState(() {
          _research = research;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(bool research) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveResearchMode(research);
      if (mounted) {
        setState(() {
          _research = research;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('計測モードを保存できませんでした（設定は変更されていません）')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AsakaoSubpage(
    eyebrow: '実験的な機能',
    title: '研究モード',
    lead: '通常モードでも心拍数を実験的に推定します。オンにすると、顔色の特徴量も取得します。',
    children: [
      AsakaoCard(
        padding: EdgeInsets.zero,
        fullBleed: true,
        child: AsakaoSwitchRow(
          title: '研究モード',
          subtitle: '次回の撮影から適用されます',
          value: _research ?? false,
          onChanged: _research == null || _saving ? null : _save,
        ),
      ),
      if (_loadFailed) ...[
        const AsakaoCaption('計測モードを読み込めませんでした'),
        TextButton(onPressed: _load, child: const Text('計測モードを再読み込み')),
      ],
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _Caution(),
      ),
    ],
  );
}

class _Caution extends StatelessWidget {
  const _Caution();

  static const _notes = [
    '診断には使用できません。値は参考値です。',
    '計測品質が不足したときは「未測定」になります。',
    'オンにしても映像は保存されません。処理はこの端末の中で行います。',
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFF8A3A14),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ご利用前に',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A3A14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final note in _notes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('・', style: TextStyle(fontSize: 13, height: 1.6)),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF4A3F39),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
