import 'package:flutter/material.dart';

/// 共有デザインの配色。画面ごとに段階導入し、ネイティブタブバーは変更しない。
abstract final class AsakaoStyle {
  // --- 既存トークン（名前・値は変更しない） ---
  static const background = Color(0xFFFFF8F3);
  static const ink = Color(0xFF2A211C);
  static const muted = Color(0xFF6E625B);
  static const coral = Color(0xFFFF8A5B);
  static const border = Color(0xFFF0E6DF);
  static const goodBackground = Color(0xFFE2F3EA);
  static const goodInk = Color(0xFF1F6B47);
  static const poorBackground = Color(0xFFFDE4E1);
  static const poorInk = Color(0xFFA3231A);

  // --- 追加トークン ---
  static const card = Colors.white;
  static const coralPale = Color(0xFFFFE7D9);
  static const coralInk = Color(0xFFB4481D);

  /// 「プライバシーポリシーを読む」「今はしない」などのリンク色。
  static const link = Color(0xFF1F6F94);
  static const linkPale = Color(0xFFE0F0F7);

  /// 「普通」相当（グレー）のチップ。中断にも使う。
  static const neutralBackground = Color(0xFFF1EAE5);
  static const neutralInk = muted;

  static const destructive = Color(0xFFC62E22);
  static const destructivePale = poorBackground;

  /// 無効ボタン・非アクティブなドット。
  static const disabled = Color(0xFFE9DFD8);

  // --- 計測（暗い背景）画面 ---
  static const scanBackground = Color(0xFF1A1512);
  static const scanSurface = Color(0xFF2B2420);
  static const scanEllipse = Color(0xFF3A2E27);
  static const scanRingIdle = Color(0xFF5A4F49);
  static const scanGreen = Color(0xFF3DB27A);
  static const scanText = Colors.white;
  static const scanMuted = Color(0xFFC9BDB5);

  // --- 文字スタイル（システムフォントのみ。太さとサイズで近似） ---
  /// 画面タイトル。丸ゴシック太字風に w900 を使う。
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    height: 1.3,
    color: ink,
  );
  static const heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.35,
    color: ink,
  );
  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: muted,
  );
  static const body = TextStyle(fontSize: 15, height: 1.6, color: ink);
  static const caption = TextStyle(fontSize: 12, height: 1.5, color: muted);
}

/// アプリ全体のテーマ。ボタン・カード・背景を共有デザインに揃える。
ThemeData asakaoTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AsakaoStyle.coral).copyWith(
    primary: AsakaoStyle.coral,
    onPrimary: AsakaoStyle.ink,
    surface: AsakaoStyle.card,
    onSurface: AsakaoStyle.ink,
    error: AsakaoStyle.destructive,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AsakaoStyle.background,
    textTheme: base.textTheme.apply(
      bodyColor: AsakaoStyle.ink,
      displayColor: AsakaoStyle.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AsakaoStyle.background,
      foregroundColor: AsakaoStyle.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AsakaoStyle.border,
      space: 1,
      thickness: 1,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AsakaoStyle.link,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AsakaoStyle.coral,
        foregroundColor: AsakaoStyle.ink,
        disabledBackgroundColor: AsakaoStyle.disabled,
        disabledForegroundColor: AsakaoStyle.muted,
        minimumSize: const Size(44, 56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
