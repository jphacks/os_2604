import 'dart:async';

import 'package:flutter/material.dart';

import '../services/settings/feedback_settings_store.dart';
import '../services/sound/sound_effects.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// 計測中に1秒ごとに鳴らす楽器を選ぶ。選ぶとその場で「ドミソド」を試し聞きできる。
class MeasureSoundPage extends StatefulWidget {
  const MeasureSoundPage({super.key, required this.store});

  final FeedbackSettingsStore store;

  @override
  State<MeasureSoundPage> createState() => _MeasureSoundPageState();
}

class _MeasureSoundPageState extends State<MeasureSoundPage> {
  FeedbackSettings _settings = SoundEffects.settings;
  bool _saving = false;
  int _preview = 0; // 試し聞きの世代。新しく選んだら前の続きは鳴らさない。

  /// 保存できたときだけ切り替える（表示と実際をそろえる）。
  Future<void> _select(MeasureInstrument instrument) async {
    if (_saving) return;
    final next = _settings.copyWith(instrument: instrument);
    setState(() => _saving = true);
    try {
      await widget.store.save(next);
      SoundEffects.settings = next;
      if (mounted) setState(() => _settings = next);
      unawaited(_playPreview(instrument));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定を保存できませんでした（変更されていません）')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ド・ミ・ソ・ド（0, 2, 4, 7 番目）を順に鳴らす。
  Future<void> _playPreview(MeasureInstrument instrument) async {
    final generation = ++_preview;
    for (final note in const [0, 2, 4, 7]) {
      if (!mounted || generation != _preview) return;
      SoundEffects.playNote(note, instrument: instrument);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    // パチンコ風は、計測完了の暗転の音まで聞かせる。
    if (instrument == MeasureInstrument.pachinko &&
        mounted &&
        generation == _preview) {
      SoundEffects.play(SoundEffect.pachinkoBlackout);
    }
  }

  @override
  void dispose() {
    _preview++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AsakaoStyle.background,
    appBar: AppBar(title: const Text('計測中の音')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              '15秒の計測中、残り秒数が変わるたびにド〜2オクターブ上のドを1音ずつ鳴らします。選ぶと試し聞きできます。',
              style: AsakaoStyle.caption,
            ),
          ),
          AsakaoCard(
            padding: EdgeInsets.zero,
            fullBleed: true,
            child: Column(
              children: [
                for (final (i, inst) in MeasureInstrument.values.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    key: ValueKey('instrument-${inst.name}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(inst.label, style: AsakaoStyle.body),
                    trailing: inst == _settings.instrument
                        ? const Icon(Icons.check, color: AsakaoStyle.coral)
                        : null,
                    selected: inst == _settings.instrument,
                    onTap: _saving ? null : () => _select(inst),
                  ),
                ],
              ],
            ),
          ),
          if (!_settings.sound)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text('効果音がオフのため、計測中の音も鳴りません。', style: AsakaoStyle.caption),
            ),
        ],
      ),
    ),
  );
}
