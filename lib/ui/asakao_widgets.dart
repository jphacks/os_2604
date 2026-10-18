import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import 'asakao_style.dart';

/// 計測品質の表示ラベル。画面間で共通（良好 / 不足 / 中断）。
String asakaoQualityLabel(MeasurementQuality q) => switch (q) {
  MeasurementQuality.good => '良好',
  MeasurementQuality.poor => '不足',
  MeasurementQuality.interrupted => '中断',
};

/// 幅いっぱいのコーラル色ピルボタン。[onPressed] が null なら無効表示。
class AsakaoPrimaryButton extends StatelessWidget {
  const AsakaoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: text,
            ),
    );
  }
}

/// 青文字のテキストリンク（「今はしない」「プライバシーポリシーを読む」など）。
class AsakaoTextLink extends StatelessWidget {
  const AsakaoTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: Text(label, textAlign: TextAlign.center),
  );
}

/// 白い角丸カード（薄い枠線つき）。[onTap] があればタップ可能。
class AsakaoCard extends StatelessWidget {
  const AsakaoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.fullBleed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// true は画面の左右いっぱいに広げ、角丸にしない（上下の線だけ）。
  final bool fullBleed;

  static const _edge = BorderSide(color: AsakaoStyle.border);

  @override
  Widget build(BuildContext context) => Material(
    color: AsakaoStyle.card,
    clipBehavior: Clip.antiAlias,
    shape: fullBleed
        ? const Border(top: _edge, bottom: _edge)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: _edge,
          ),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// カード上部などに置く小さな見出し。
class AsakaoSectionLabel extends StatelessWidget {
  const AsakaoSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(text, style: AsakaoStyle.sectionLabel),
    ),
  );
}

/// 計測品質のチップ。良好=緑、不足=赤、中断=グレー。色だけでなく文言でも区別する。
class AsakaoQualityChip extends StatelessWidget {
  const AsakaoQualityChip(this.quality, {super.key});

  final MeasurementQuality quality;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (quality) {
      MeasurementQuality.good => (
        AsakaoStyle.goodBackground,
        AsakaoStyle.goodInk,
      ),
      MeasurementQuality.poor => (
        AsakaoStyle.poorBackground,
        AsakaoStyle.poorInk,
      ),
      MeasurementQuality.interrupted => (
        AsakaoStyle.neutralBackground,
        AsakaoStyle.neutralInk,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          asakaoQualityLabel(quality),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// 設定画面風の行。右に値とシェブロン。[destructive] は中央寄せの赤文字（削除など）。
/// [subtitle] があると高さは60以上、なければ52以上。[trailing] は値の代わりに右へ置く。
class AsakaoListRow extends StatelessWidget {
  const AsakaoListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.inset = 16,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// 左右の余白。設定画面は20にそろえる。
  final double inset;

  @override
  Widget build(BuildContext context) {
    final content = destructive
        ? Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AsakaoStyle.destructive,
              ),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AsakaoStyle.body),
                    if (subtitle != null)
                      Text(subtitle!, style: AsakaoStyle.caption),
                  ],
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AsakaoStyle.muted,
                      ),
                    ),
                  ),
                ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: trailing,
                ),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AsakaoStyle.muted,
                ),
              ),
            ],
          );
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 52 : 60),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: inset,
              vertical: subtitle == null ? 12 : 8,
            ),
            child: Align(alignment: Alignment.centerLeft, child: content),
          ),
        ),
      ),
    );
  }
}

/// スイッチ付きの行（バンドの中に置く）。行のどこを押しても切り替わる。
/// [onChanged] が null のときは無効表示。
class AsakaoSwitchRow extends StatelessWidget {
  const AsakaoSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.inset = 20,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double inset;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      // 行全体のタップは見た目だけ。操作はスイッチ側の意味情報に任せる。
      excludeFromSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 52 : 60),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: subtitle == null ? 6 : 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AsakaoStyle.body),
                    if (subtitle != null)
                      Text(subtitle!, style: AsakaoStyle.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                activeTrackColor: AsakaoStyle.coral,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// バンドの下に置く小さな説明文。[icon] があれば文頭に添える。
class AsakaoCaption extends StatelessWidget {
  const AsakaoCaption(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(icon, size: 14, color: AsakaoStyle.muted),
          ),
        Expanded(child: Text(text, style: AsakaoStyle.caption)),
      ],
    ),
  );
}

/// 接続状態の小さな丸。色だけに頼らず、必ず隣に文言を置く。
class AsakaoStatusDot extends StatelessWidget {
  const AsakaoStatusDot({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: on ? AsakaoStyle.scanGreen : const Color(0xFFB8ABA3),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 8),
    ),
  );
}

/// [AsakaoListRow] を1枚のカードにまとめ、行間に区切り線を引く。
class AsakaoListGroup extends StatelessWidget {
  const AsakaoListGroup({
    super.key,
    required this.children,
    this.fullBleed = false,
  });

  final List<Widget> children;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) => AsakaoCard(
    padding: EdgeInsets.zero,
    fullBleed: fullBleed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
      ],
    ),
  );
}

/// [wilted] は今日まだチェックしていない履歴カード用（灰色のしおれた花）。
enum AsakaoMascotMood { normal, happy, sad, busy, wilted }

/// マスコット（あさかお）。表情ごとの画像を出す。表示は装飾でスクリーンリーダーには読ませない。
class AsakaoMascot extends StatelessWidget {
  const AsakaoMascot({
    super.key,
    this.mood = AsakaoMascotMood.normal,
    this.size = 88,
  });

  final AsakaoMascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/mascot/${mood.name}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 画像を読めなくても画面は止めない。枠だけ確保する。
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    ),
  );
}

/// オンボーディングのページドット。現在ページは横長のコーラル。
class AsakaoStepDots extends StatelessWidget {
  const AsakaoStepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${index + 1} / $count ページ',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: i == index ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index ? AsakaoStyle.coral : AsakaoStyle.disabled,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    ),
  );
}

/// 画面が出てから [delay] 後に、下から少し浮き上がりながらフェードインする。
/// 遅延も同じアニメーションの中で扱う（タイマーを使わない）。
class AsakaoReveal extends StatefulWidget {
  const AsakaoReveal({
    super.key,
    required this.delay,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.rise = 16,
  });

  final Duration delay;
  final Duration duration;

  /// 下からずらして始める距離（論理ピクセル）。
  final double rise;
  final Widget child;

  @override
  State<AsakaoReveal> createState() => _AsakaoRevealState();
}

class _AsakaoRevealState extends State<AsakaoReveal>
    with SingleTickerProviderStateMixin {
  late final _total = widget.delay + widget.duration;
  late final _controller = AnimationController(vsync: this, duration: _total)
    ..forward();
  late final _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / _total.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (_, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _progress.value) * widget.rise),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// 「1 2 3」の手順カード（設定アプリでオンにする方法など）。
class AsakaoNumberedSteps extends StatelessWidget {
  const AsakaoNumberedSteps({
    super.key,
    required this.title,
    required this.steps,
  });

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) => AsakaoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AsakaoStyle.sectionLabel),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AsakaoStyle.linkPale,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AsakaoStyle.link,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: AsakaoStyle.body)),
              ],
            ),
          ),
      ],
    ),
  );
}
