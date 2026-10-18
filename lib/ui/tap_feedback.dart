import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/sound/sound_effects.dart';

/// アプリ全体で、ボタンを押したときに「タップ音」と一瞬の振動を出す。
///
/// 指を離した位置が、押せる部品の上だったときだけ鳴らす。押せるかどうかは、読み上げ用の
/// 情報（押せる状態のボタン、またはタップ操作がある）で判断する。動かした（スクロールした）指や、
/// 押せないボタンでは鳴らさない。
class TapFeedback extends StatefulWidget {
  const TapFeedback({super.key, required this.child});

  final Widget child;

  @override
  State<TapFeedback> createState() => _TapFeedbackState();
}

class _TapFeedbackState extends State<TapFeedback> {
  final _downAt = <int, Offset>{};

  void _onUp(PointerUpEvent event) {
    final start = _downAt.remove(event.pointer);
    if (start == null || (event.position - start).distance > kTouchSlop) {
      return;
    }
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    for (final entry in result.path) {
      if (_tappable(entry.target)) {
        SoundEffects.play(SoundEffect.tap);
        return;
      }
    }
  }

  static bool _tappable(HitTestTarget target) {
    if (target is RenderSemanticsGestureHandler) return target.onTap != null;
    if (target is RenderSemanticsAnnotations) {
      final p = target.properties;
      if (p.enabled == false) return false;
      return p.onTap != null || p.button == true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => _downAt[e.pointer] = e.position,
    onPointerCancel: (e) => _downAt.remove(e.pointer),
    onPointerUp: _onUp,
    child: widget.child,
  );
}
