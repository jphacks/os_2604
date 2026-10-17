import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// アプリの効果音。音源は assets/sounds/。
enum SoundEffect {
  /// 3-3 計測中断。
  pause('pause.mp3'),

  /// 15秒の計測が終わったとき。
  measureDone('measure_done.mp3'),

  /// 顔・明るさ・角度の3つの条件がそろったとき。
  ready('ready.mp3'),

  /// 1-7 初期設定の完了画面。
  setupDone('setup_done.mp3'),

  /// 今日のつぼみがアサガオに咲くとき。
  bloom('bloom.mp3');

  const SoundEffect(this.file);
  final String file;
}

/// 効果音を鳴らす。iOS 以外や失敗時は何もしない（画面の動きを止めない）。
abstract final class SoundEffects {
  static const _channel = MethodChannel('jp.jphacks.os_2604/sound_effects');

  /// テストで鳴った音を確かめるときに差し替える。
  @visibleForTesting
  static void Function(SoundEffect effect)? debugOnPlay;

  static void play(SoundEffect effect) {
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
}
