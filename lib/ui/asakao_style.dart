import 'package:flutter/material.dart';

/// 共有デザインの配色。画面ごとに段階導入し、ネイティブタブバーは変更しない。
abstract final class AsakaoStyle {
  static const background = Color(0xFFFFF8F3);
  static const ink = Color(0xFF2A211C);
  static const muted = Color(0xFF6E625B);
  static const coral = Color(0xFFFF8A5B);
  static const border = Color(0xFFF0E6DF);
  static const goodBackground = Color(0xFFE2F3EA);
  static const goodInk = Color(0xFF1F6B47);
  static const poorBackground = Color(0xFFFDE4E1);
  static const poorInk = Color(0xFFA3231A);
}
