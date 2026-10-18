import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/feedback_settings_store.dart';

/// アプリの効果音。音源は assets/sounds/。[haptic] は同時に鳴らす振動。
enum SoundEffect {
  /// 3-3 計測中断。
  pause('pause.mp3', AppHaptic.medium),

  /// 15秒の計測が終わったとき。
  measureDone('measure_done.mp3', AppHaptic.heavy),

  /// 顔・明るさ・角度の3つの条件がそろったとき。すぐ計測が始まるので振動はしない
  /// （端末が揺れて顔の位置や光が変わらないように）。
  ready('ready.mp3', null),

  /// 1-7 初期設定の完了画面。
  setupDone('setup_done.mp3', AppHaptic.light),

  /// 今日のつぼみがアサガオに咲くとき。振動は花が開く瞬間に別に鳴らす。
  bloom('bloom.mp3', null),

  /// 計測中の音が「パチンコ風」のときの計測完了。画面を暗転させる（[measureDone] の代わり）。
  pachinkoBlackout('pachinko_blackout.mp3', AppHaptic.heavy),

  /// パチンコ風で、暗転のあと体調の入力（4-1）へ進むとき。
  pachinkoResult('pachinko_result.mp3', null),

  /// ボタンを押したとき（一瞬だけ振動）。
  tap('tap.mp3', AppHaptic.tick);

  const SoundEffect(this.file, this.haptic);
  final String file;
  final AppHaptic? haptic;
}

/// [tick] はボタンを押したときの、ごく短い振動。
enum AppHaptic { tick, light, medium, heavy }

/// 効果音と振動。設定でそれぞれ止められる。iOS 以外や失敗時は何もしない（画面の動きを止めない）。
abstract final class SoundEffects {
  static const _channel = MethodChannel('jp.jphacks.os_2604/sound_effects');

  /// 起動時と設定の変更時に更新する。読めないときは両方オン。
  static FeedbackSettings settings = const FeedbackSettings();

  /// テストで鳴った音を確かめるときに差し替える。
  @visibleForTesting
  static void Function(SoundEffect effect)? debugOnPlay;

  /// テストで計測中の音（何番目の音か）を確かめるときに差し替える。
  @visibleForTesting
  static void Function(MeasureInstrument instrument, int note)? debugOnNote;

  /// 計測中の1秒ごとの音。[note] は 0（低いド）〜14（2オクターブ上のド）。
  /// 振動はしない（端末が揺れて計測に影響しないように）。
  static void playNote(int note, {MeasureInstrument? instrument}) {
    final inst = instrument ?? settings.instrument;
    final folder = inst.folder;
    if (!settings.sound || folder == null || note < 0 || note > 14) return;
    final hook = debugOnNote;
    if (hook != null) {
      hook(inst, note);
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel
        .invokeMethod<void>(
          'play',
          'assets/sounds/scale/$folder/${inst.fileFor(note)}',
        )
        .catchError((Object _) {});
  }

  /// テストで振動を確かめるときに差し替える。
  @visibleForTesting
  static void Function(AppHaptic haptic)? debugOnHaptic;

  /// パチンコ風の演出（暗転 → 体調の入力）にするか。効果音がオフなら通常どおり。
  static bool get pachinkoFinish =>
      settings.sound && settings.instrument == MeasureInstrument.pachinko;

  static void play(SoundEffect effect) {
    final haptic = effect.haptic;
    if (haptic != null) SoundEffects.haptic(haptic);
    if (!settings.sound) return;
    final hook = debugOnPlay;
    if (hook != null) {
      hook(effect);
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel
        .invokeMethod<void>('play', 'assets/sounds/${effect.file}')
        .catchError((Object _) {});
  }

  static void haptic(AppHaptic haptic) {
    if (!settings.haptics) return;
    final hook = debugOnHaptic;
    if (hook != null) {
      hook(haptic);
      return;
    }
    final Future<void> done = switch (haptic) {
      AppHaptic.tick => HapticFeedback.selectionClick(),
      AppHaptic.light => HapticFeedback.lightImpact(),
      AppHaptic.medium => HapticFeedback.mediumImpact(),
      AppHaptic.heavy => HapticFeedback.heavyImpact(),
    };
    done.catchError((Object _) {});
  }
}
