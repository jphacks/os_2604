import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'asakao_style.dart';

/// 「パチンコ風」の演出。画像素材は使わず、すべて描画で作ったオリジナル。

/// 計測完了の暗転。上下から黒い帯が閉じ、中央で青白い十字の閃光が弾けてから真っ暗になる。
/// [progress] は 0（始まり）〜 1（真っ暗）。
class PachinkoBlackout extends StatelessWidget {
  const PachinkoBlackout({super.key, required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (_, _) => CustomPaint(
      size: Size.infinite,
      painter: _BlackoutPainter(progress.value),
    ),
  );
}

class _BlackoutPainter extends CustomPainter {
  const _BlackoutPainter(this.t);

  final double t;

  // 帯が閉じきる時刻と、閃光の始まり・終わり（progress の割合）。
  static const _closed = 0.42;
  static const _flashFrom = 0.36;
  static const _flashTo = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 上下の黒い帯（加速しながら閉じる）。
    final close = Curves.easeInCubic.transform((t / _closed).clamp(0.0, 1.0));
    final bar = h / 2 * close;
    final black = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, bar), black);
    canvas.drawRect(Rect.fromLTWH(0, h - bar, w, bar), black);

    // 閃光：急に強くなって、ゆっくり消える。
    final f = ((t - _flashFrom) / (_flashTo - _flashFrom)).clamp(0.0, 1.0);
    if (f <= 0 || f >= 1) return;
    final strength = f < 0.25
        ? Curves.easeOut.transform(f / 0.25)
        : 1 - Curves.easeIn.transform((f - 0.25) / 0.75);
    final grow = Curves.easeOutCubic.transform(math.min(1, f * 2.2));

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final glow = Paint()..blendMode = BlendMode.plus;

    // 放射状の光の筋。
    final rays = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(7);
    for (var i = 0; i < 40; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final length = (0.25 + rnd.nextDouble() * 0.45) * w * grow;
      rays
        ..strokeWidth = 0.6 + rnd.nextDouble() * 1.6
        ..color = const Color(0xFF3D8BFF)
            .withValues(alpha: (0.25 + rnd.nextDouble() * 0.35) * strength);
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * length,
        rays,
      );
    }

    // 中心のにじみ。
    final radius = 40 + 110 * grow;
    glow.shader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: strength),
        const Color(0xFF7FD4FF).withValues(alpha: 0.75 * strength),
        const Color(0xFF1E5BFF).withValues(alpha: 0.35 * strength),
        const Color(0x001E5BFF),
      ],
      stops: const [0, 0.18, 0.5, 1],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    // 横に長く伸びる光の線。
    void streak(Size s, {required bool horizontal}) {
      final rect = Rect.fromCenter(
        center: center,
        width: s.width,
        height: s.height,
      );
      glow.shader =
          (horizontal
                  ? LinearGradient(
                      colors: [
                        const Color(0x001E7BFF),
                        const Color(0xFF4FB4FF).withValues(alpha: strength),
                        Colors.white.withValues(alpha: strength),
                        const Color(0xFF4FB4FF).withValues(alpha: strength),
                        const Color(0x001E7BFF),
                      ],
                      stops: const [0, 0.35, 0.5, 0.65, 1],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x001E7BFF),
                        const Color(0xFF4FB4FF).withValues(alpha: strength),
                        Colors.white.withValues(alpha: strength),
                        const Color(0xFF4FB4FF).withValues(alpha: strength),
                        const Color(0x001E7BFF),
                      ],
                      stops: const [0, 0.35, 0.5, 0.65, 1],
                    ))
              .createShader(rect);
      canvas.drawOval(rect, glow);
    }

    streak(Size(w * 1.6 * grow, 10 + 8 * strength), horizontal: true);
    streak(Size(w * 1.6 * grow, 3), horizontal: true);
    streak(Size(14 + 6 * strength, h * 0.42 * grow), horizontal: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlackoutPainter old) => old.t != t;
}

/// 遷移後の背景。金とオレンジの放射光がゆっくり回り、きらめきが瞬く。
/// 「視差効果を減らす」設定では止める。
class PachinkoBackground extends StatefulWidget {
  const PachinkoBackground({super.key, required this.child});

  final Widget child;

  @override
  State<PachinkoBackground> createState() => _PachinkoBackgroundState();
}

class _PachinkoBackgroundState extends State<PachinkoBackground>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SunburstPainter(_controller), child: widget.child);
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height * 0.18);
    final reach = size.longestSide * 1.3;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.64),
          radius: 1.2,
          colors: const [
            Color(0xFFFFF7C9),
            Color(0xFFFFD54F),
            Color(0xFFFFA000),
            Color(0xFFE65100),
          ],
          stops: const [0, 0.25, 0.6, 1],
        ).createShader(rect),
    );

    // 回る光の帯（明るい扇形を交互に）。
    const count = 18;
    final rays = Paint()..color = const Color(0x40FFFFFF);
    for (var i = 0; i < count; i += 2) {
      final a = (i / count + t) * 2 * math.pi;
      final b = a + 2 * math.pi / count;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + math.cos(a) * reach,
            center.dy + math.sin(a) * reach,
          )
          ..lineTo(
            center.dx + math.cos(b) * reach,
            center.dy + math.sin(b) * reach,
          )
          ..close(),
        rays,
      );
    }

    // 瞬くきらめき（4方向の光）。
    final rnd = math.Random(11);
    final sparkle = Paint()..color = Colors.white;
    for (var i = 0; i < 26; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final phase = rnd.nextDouble();
      final twinkle = (math.sin((t * 6 + phase) * 2 * math.pi) + 1) / 2;
      final r = (3 + rnd.nextDouble() * 7) * twinkle;
      if (r < 0.5) continue;
      sparkle.color = Colors.white.withValues(alpha: 0.85 * twinkle);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - r * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + r * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - r * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r * 2)
          ..close(),
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(_SunburstPainter old) => false;
}

/// 遷移後の見出し。金のふちどりに虹色の太字。出てくるときに弾み、光が横に流れる。
class PachinkoBanner extends StatefulWidget {
  const PachinkoBanner({super.key});

  @override
  State<PachinkoBanner> createState() => _PachinkoBannerState();
}

class _PachinkoBannerState extends State<PachinkoBanner>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  late final _pop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.35, curve: Curves.elasticOut),
  );
  late final _shine = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _rainbow = [
    Color(0xFFFF1744),
    Color(0xFFFF9100),
    Color(0xFFFFEA00),
    Color(0xFF00E676),
    Color(0xFF00B0FF),
    Color(0xFF651FFF),
    Color(0xFFD500F9),
  ];

  Widget _outlined(
    String text, {
    required double size,
    required List<Color> fill,
    double shine = -1,
  }) {
    final style = TextStyle(
      fontFamily: AsakaoStyle.displayFont,
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: 1,
    );
    return Stack(
      children: [
        // 外側の濃い茶色のふち。
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.24
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF5D2E00),
          ),
        ),
        // 金のふち。
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.13
              ..strokeJoin = StrokeJoin.round
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF59D),
                  Color(0xFFFFB300),
                  Color(0xFF8D5A00),
                ],
              ).createShader(Rect.fromLTWH(0, 0, size * text.length, size)),
          ),
        ),
        // 中の色と、横に流れる光。
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              LinearGradient(colors: fill).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
        if (shine > -1 && shine < 2)
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1 + shine * 2 - 0.4, -0.3),
              end: Alignment(-1 + shine * 2 + 0.4, 0.3),
              colors: const [
                Color(0x00FFFFFF),
                Color(0xCCFFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(bounds),
            child: Text(text, style: style.copyWith(color: Colors.white)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '15秒チェック 完全達成 ボーナス',
    excludeSemantics: true,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Transform.scale(
        scale: 0.3 + 0.7 * _pop.value,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _outlined(
                '15秒チェック',
                size: 22,
                fill: const [Color(0xFFFFFDE7), Color(0xFFFFD54F)],
              ),
              const SizedBox(height: 4),
              _outlined(
                '完全達成!!',
                size: 54,
                fill: _rainbow,
                shine: _shine.value * 1.6,
              ),
              _outlined(
                'BONUS',
                size: 32,
                fill: const [Color(0xFFFFF59D), Color(0xFFFFB300)],
                shine: _shine.value * 1.6 - 0.3,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
