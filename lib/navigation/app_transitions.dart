import 'package:flutter/cupertino.dart';

/// 画面遷移の種類（デザインの「あさかお 画面遷移仕様」に対応）。
/// - push: 右から入る。戻るは左端スワイプ可。
/// - fade: 同じ場所で0.25秒クロスフェード。
/// - cover: 下から出る。閉じるときは下へ。
abstract final class AppTransitions {
  static const fadeDuration = Duration(milliseconds: 250);
  static const coverDuration = Duration(milliseconds: 400);

  static Route<T> push<T>(WidgetBuilder builder, {RouteSettings? settings}) =>
      CupertinoPageRoute<T>(builder: builder, settings: settings);

  /// [dismissDown] は cover の中で fade した画面用。閉じると cover と同じく下へ消える。
  static Route<T> fade<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
    bool dismissDown = false,
  }) => PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: fadeDuration,
    reverseTransitionDuration: dismissDown ? coverDuration : fadeDuration,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (_, animation, _, child) => dismissDown
        ? DualTransitionBuilder(
            animation: animation,
            forwardBuilder: (_, a, child) =>
                FadeTransition(opacity: a, child: child),
            reverseBuilder: (_, a, child) => SlideTransition(
              position: _slideDown.animate(
                CurvedAnimation(parent: a, curve: Curves.easeInCubic),
              ),
              child: child,
            ),
            child: child,
          )
        : FadeTransition(opacity: animation, child: child),
  );

  static Route<T> cover<T>(WidgetBuilder builder, {RouteSettings? settings}) =>
      PageRouteBuilder<T>(
        settings: settings,
        fullscreenDialog: true,
        transitionDuration: coverDuration,
        reverseTransitionDuration: coverDuration,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: _slideUp.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        ),
      );

  /// 同じ画面の中で状態だけが変わるときの fade。子の key で切り替えを判定する。
  static Widget fadeSwitch({required Widget child}) => AnimatedSwitcher(
    duration: fadeDuration,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    child: child,
  );

  static final _slideUp = Tween(begin: const Offset(0, 1), end: Offset.zero);
  static final _slideDown = Tween(begin: Offset.zero, end: const Offset(0, 1));
}
