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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AsakaoStyle.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AsakaoStyle.border),
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
class AsakaoListRow extends StatelessWidget {
  const AsakaoListRow({
    super.key,
    required this.title,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

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
              Expanded(child: Text(title, style: AsakaoStyle.body)),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AsakaoStyle.muted,
                    ),
                  ),
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
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(alignment: Alignment.centerLeft, child: content),
        ),
      ),
    );
  }
}

/// [AsakaoListRow] を1枚のカードにまとめ、行間に区切り線を引く。
class AsakaoListGroup extends StatelessWidget {
  const AsakaoListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AsakaoCard(
    padding: EdgeInsets.zero,
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

enum AsakaoMascotMood { normal, happy, sad, busy }

/// マスコット（あさかお）の仮表示。キャラクター画像が届いたらこの中身を
/// 画像に差し替える（呼び出し側の変更は不要）。表示は装飾でスクリーンリーダーには読ませない。
class AsakaoMascot extends StatelessWidget {
  const AsakaoMascot({
    super.key,
    this.mood = AsakaoMascotMood.normal,
    this.size = 88,
  });

  final AsakaoMascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (flower, color, badge, badgeColor) = switch (mood) {
      AsakaoMascotMood.normal => (
        Icons.local_florist,
        AsakaoStyle.coral,
        null,
        null,
      ),
      AsakaoMascotMood.happy => (
        Icons.local_florist,
        AsakaoStyle.coral,
        Icons.favorite,
        AsakaoStyle.destructive,
      ),
      AsakaoMascotMood.sad => (
        Icons.local_florist_outlined,
        AsakaoStyle.muted,
        Icons.water_drop,
        AsakaoStyle.link,
      ),
      AsakaoMascotMood.busy => (
        Icons.local_florist,
        AsakaoStyle.coral,
        Icons.hourglass_empty,
        AsakaoStyle.muted,
      ),
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(flower, size: size, color: color),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Icon(badge, size: size * 0.3, color: badgeColor),
              ),
          ],
        ),
      ),
    );
  }
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
          Container(
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
