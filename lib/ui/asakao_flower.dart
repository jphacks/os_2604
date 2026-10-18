import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../services/sound/sound_effects.dart';

/// 「今週咲いた花」の1日分。デザインの SVG（32×32）をそのまま描く。
enum AsakaoFlowerState {
  /// 有効な記録がある日。
  bloomed,

  /// 記録がない日（灰色のつぼみ）。
  bud,

  /// まだ記録していない今日（色のついたつぼみ）。
  todayBud,
}

class AsakaoDayFlower extends StatelessWidget {
  const AsakaoDayFlower({super.key, required this.state, this.size = 30});

  final AsakaoFlowerState state;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FlowerPainter(state)),
  );
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter(this.state);

  final AsakaoFlowerState state;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    state == AsakaoFlowerState.bloomed ? _bloom(canvas) : _bud(canvas);
  }

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _bud(Canvas canvas) {
    final today = state == AsakaoFlowerState.todayBud;
    final stem = today ? const Color(0xFF6EA368) : const Color(0xFFA9BBA4);
    canvas.drawLine(
      const Offset(16, 25.5),
      const Offset(16, 31),
      _stroke(stem, 1.6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(16, 2.5)
        ..cubicTo(19.5, 7, 20.8, 13, 19.2, 19.5)
        ..cubicTo(18.4, 22.8, 13.6, 22.8, 12.8, 19.5)
        ..cubicTo(11.2, 13, 12.5, 7, 16, 2.5)
        ..close(),
      _fill(today ? const Color(0xFFFFC3A6) : const Color(0xFFE8DED7)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(16, 3)
        ..cubicTo(18.6, 8, 15, 12.5, 19, 18.6)
        ..moveTo(16, 3)
        ..cubicTo(15.2, 9, 18.6, 13.6, 13.3, 19.8)
        ..moveTo(16.2, 3.4)
        ..cubicTo(14, 8.4, 13.6, 13.6, 15.8, 22.2),
      _stroke(today ? const Color(0xFFEC8E69) : const Color(0xFFCBBDB4), 0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(14.3, 8.2)
        ..cubicTo(13.8, 11.2, 13.8, 14.8, 14.5, 17.8),
      _stroke(const Color(0x8CFFFFFF), 0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(16, 26)
        ..cubicTo(12.5, 25.6, 10.8, 22.6, 12, 19.4)
        ..cubicTo(13.8, 21, 15.3, 23, 16, 26)
        ..close()
        ..moveTo(16, 26)
        ..cubicTo(19.5, 25.6, 21.2, 22.6, 20, 19.4)
        ..cubicTo(18.2, 21, 16.7, 23, 16, 26)
        ..close(),
      _fill(stem),
    );
  }

  void _bloom(Canvas canvas) {
    final outline = Path()..addPolygon(_points(_outline), true);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFAF3),
            Color(0xFFFFE4D2),
            Color(0xFFFF9C70),
            Color(0xFFEC6A3C),
          ],
          stops: [0, 0.2, 0.55, 1],
        ).createShader(outline.getBounds()),
    );
    canvas.drawPath(outline, _stroke(const Color(0xFFDA6034), 0.6));
    canvas.drawPath(
      Path()..addPolygon(_points(_star), true),
      _fill(const Color(0x8CFFF4EA)),
    );
    final ribs = _stroke(const Color(0x59D2552B), 0.7);
    for (final (a, b) in _ribs) {
      canvas.drawLine(a, b, ribs);
    }
    canvas.drawCircle(
      const Offset(16, 16),
      3.2,
      _fill(const Color(0xFFFFFCF6)),
    );
    canvas.drawCircle(
      const Offset(16, 16),
      1.2,
      _fill(const Color(0xFFF3D98E)),
    );
  }

  static List<Offset> _points(List<double> xy) => [
    for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1]),
  ];

  static const _star = [
    16.00, 3.40, 17.76, 13.57, 27.98, 12.11, 18.85, 16.93, 23.41, 26.19, //
    16.00, 19.00, 8.59, 26.19, 13.15, 16.93, 4.02, 12.11, 14.24, 13.57,
  ];

  static const _ribs = [
    (Offset(18.70, 12.28), Offset(23.76, 5.32)),
    (Offset(20.37, 17.42), Offset(28.55, 20.08)),
    (Offset(16.00, 20.60), Offset(16.00, 29.20)),
    (Offset(11.63, 17.42), Offset(3.45, 20.08)),
    (Offset(13.30, 12.28), Offset(8.24, 5.32)),
  ];

  static const _outline = [
    16.00, 1.10, 17.04, 1.19, 18.04, 1.45, 19.00, 1.87, 19.90, 2.39, //
    20.73, 2.99, 21.51, 3.62, 22.25, 4.25, 22.97, 4.84, 23.70, 5.40,
    24.46, 5.92, 25.25, 6.43, 26.07, 6.93, 26.91, 7.48, 27.74, 8.08,
    28.51, 8.78, 29.20, 9.56, 29.76, 10.44, 30.17, 11.40, 30.40, 12.41,
    30.47, 13.45, 30.37, 14.49, 30.15, 15.51, 29.84, 16.48, 29.48, 17.42,
    29.11, 18.31, 28.76, 19.18, 28.46, 20.05, 28.20, 20.93, 27.96, 21.83,
    27.73, 22.77, 27.48, 23.74, 27.16, 24.72, 26.74, 25.67, 26.20, 26.57,
    25.54, 27.37, 24.76, 28.05, 23.87, 28.59, 22.90, 28.97, 21.88, 29.20,
    20.84, 29.30, 19.82, 29.31, 18.82, 29.25, 17.85, 29.18, 16.92, 29.12,
    16.00, 29.10, 15.08, 29.12, 14.15, 29.18, 13.18, 29.25, 12.18, 29.31,
    11.16, 29.30, 10.12, 29.20, 9.10, 28.97, 8.13, 28.59, 7.24, 28.05,
    6.46, 27.37, 5.80, 26.57, 5.26, 25.67, 4.84, 24.72, 4.52, 23.74,
    4.27, 22.78, 4.04, 21.83, 3.80, 20.93, 3.54, 20.05, 3.24, 19.18,
    2.89, 18.31, 2.52, 17.42, 2.16, 16.48, 1.85, 15.51, 1.63, 14.49,
    1.53, 13.45, 1.60, 12.41, 1.83, 11.40, 2.24, 10.44, 2.80, 9.56,
    3.49, 8.77, 4.26, 8.08, 5.09, 7.48, 5.93, 6.93, 6.75, 6.43,
    7.54, 5.92, 8.30, 5.40, 9.03, 4.84, 9.75, 4.25, 10.49, 3.62,
    11.27, 2.99, 12.10, 2.39, 13.00, 1.87, 13.96, 1.45, 14.96, 1.19,
  ];

  @override
  bool shouldRepaint(_FlowerPainter old) => old.state != state;
}

/// 「今週咲いた花」の今日。チェックが済むと、見えている状態でつぼみが花に開く。
///
/// 計測の画面に隠れている間に記録が増えても、[visible] になるまで開かずに待つ。
/// 最初から咲いている（もう記録済みの）ときはアニメーションしない。
class AsakaoTodayBloom extends StatefulWidget {
  const AsakaoTodayBloom({
    super.key,
    required this.bloomed,
    required this.visible,
    this.size = 30,
  });

  final bool bloomed;
  final bool visible;
  final double size;

  @override
  State<AsakaoTodayBloom> createState() => _AsakaoTodayBloomState();
}

class _AsakaoTodayBloomState extends State<AsakaoTodayBloom>
    with TickerProviderStateMixin {
  /// 咲く間は画面全体を暗くし、今日の花だけを明るく残す。
  /// 「蕾」の効果音（約7秒）が鳴り終わるまで操作を止める。
  static const spotlightDuration = Duration(milliseconds: 7100);

  OverlayEntry? _spotlight;
  AnimationController? _spotlightController;

  // 「蕾」の効果音（約7秒）に合わせる。音は 0〜1.5秒で盛り上がり、3秒ごろまで続き、
  // 6.5秒までに消える。0.4秒は待ち（cover が下へ閉じきるまで）、つぼみがふくらみ、
  // 音の山で花が開き、余韻に合わせて光がゆっくり引いていく。
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6500),
    value: widget.bloomed ? 1 : 0,
  );
  late final _swell = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.06, 0.24, curve: Curves.easeInOut),
  );
  late final _budOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 0.32, curve: Curves.easeIn),
  );
  late final _flowerIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 0.45, curve: Curves.easeOutBack),
  );
  late final _afterglow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void didUpdateWidget(AsakaoTodayBloom old) {
    super.didUpdateWidget(old);
    if (!widget.bloomed) {
      _controller.value = 0; // 記録を消したときはつぼみに戻す
    } else if (widget.visible && _controller.value == 0) {
      _controller.forward();
      SoundEffects.play(SoundEffect.bloom);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSpotlight());
    }
  }

  void _showSpotlight() {
    if (!mounted || _spotlight != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject();
    final overlayBox = overlay?.context.findRenderObject();
    if (overlay == null || box is! RenderBox || overlayBox is! RenderBox) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    // 花の上の曜日も含めて、少し広めに明るく残す。
    final hole = Rect.fromLTRB(
      origin.dx - 18,
      origin.dy - 28,
      origin.dx + box.size.width + 18,
      origin.dy + box.size.height + 16,
    );
    final controller = AnimationController(
      vsync: this,
      duration: spotlightDuration,
    );
    _spotlightController = controller;
    _spotlight = OverlayEntry(
      builder: (_) => _BloomSpotlight(animation: controller, hole: hole),
    );
    overlay.insert(_spotlight!);
    controller.forward().whenCompleteOrCancel(_hideSpotlight);
  }

  void _hideSpotlight() {
    _spotlight?.remove();
    _spotlight?.dispose();
    _spotlight = null;
    _spotlightController?.dispose();
    _spotlightController = null;
  }

  @override
  void dispose() {
    _hideSpotlight();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) {
      final t = _controller.value;
      final swell = _swell.value;
      final bud = 1 - _budOut.value;
      final flower = _flowerIn.value;
      // 花が開いたあと、光が強まってから余韻とともに消える。
      final glow = t <= 0.3 || t >= 1
          ? 0.0
          : math.sin(math.pi * _afterglow.value).clamp(0.0, 1.0);
      // 開いた花は、音が消えるまでゆっくり小さく脈打つ。
      final breathe = flower >= 1 && t < 1
          ? 1 + 0.05 * math.sin(t * math.pi * 8) * (1 - t)
          : 1.0;
      return SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (glow > 0)
              IgnorePointer(
                child: Transform.scale(
                  scale: 1.6 + 0.6 * glow,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFC9A8).withValues(alpha: 0.9 * glow),
                          const Color(0x00FFC9A8),
                        ],
                      ),
                    ),
                    child: SizedBox.square(dimension: widget.size),
                  ),
                ),
              ),
            if (bud > 0)
              Opacity(
                opacity: bud,
                child: Transform.rotate(
                  // ふくらみながら小さく揺れる。
                  angle: 0.08 * math.sin(swell * math.pi * 6) * swell,
                  child: Transform.scale(
                    scale: (1 + 0.25 * swell) * (0.7 + 0.3 * bud),
                    child: AsakaoDayFlower(
                      state: AsakaoFlowerState.todayBud,
                      size: widget.size,
                    ),
                  ),
                ),
              ),
            if (flower > 0)
              Opacity(
                opacity: flower.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: (1 - flower) * -1.2,
                  child: Transform.scale(
                    scale: flower * breathe,
                    child: AsakaoDayFlower(
                      state: AsakaoFlowerState.bloomed,
                      size: widget.size,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 咲く間の暗幕。今日の花のまわりだけ穴をあけ、下の画面への操作をすべて止める。
class _BloomSpotlight extends StatelessWidget {
  const _BloomSpotlight({required this.animation, required this.hole});

  final Animation<double> animation;
  final Rect hole;

  // 始めの 0.3 秒で暗くし、最後の 0.4 秒で明るく戻す。
  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 4),
    TweenSequenceItem(tween: ConstantTween(1), weight: 90),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 6),
  ]);

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    child: AnimatedBuilder(
      animation: animation,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _SpotlightPainter(
          hole: hole,
          opacity: _opacity.evaluate(animation),
        ),
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.opacity});

  final Rect hole;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));
    canvas.drawPath(
      scrim,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.55 * opacity),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.opacity != opacity || old.hole != hole;
}
