import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navigation/app_transitions.dart';
import '../screens/onboarding_screen.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/onboarding_store.dart';
import '../services/settings/reminder_settings_store.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// Waits for durable acknowledgement before entering the home screen.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.store,
    required this.homeBuilder,
    required this.reminderService,
    required this.reminderStore,
    this.requestCameraPermission = requestSystemCameraPermission,
  });

  final OnboardingStore store;
  final WidgetBuilder homeBuilder;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;
  final Future<bool?> Function() requestCameraPermission;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate>
    with SingleTickerProviderStateMixin {
  /// 1-7 → 1-8。初回設定（cover）を下へ閉じて、下の履歴を見せる。
  late final _dismiss = AnimationController(
    vsync: this,
    duration: AppTransitions.coverDuration,
  );
  final _onboardingKey = GlobalKey();
  bool? _completed;
  bool _loading = false;
  bool _saving = false;

  /// 初回設定をこの起動で終えた直後だけ、カメラボタンの案内を出す。
  bool _showTip = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dismiss.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store)) {
      _generation++;
      _completed = null;
      _loading = false;
      _saving = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || _saving) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final completed = await widget.store.hasCompletedOnboarding();
      if (!mounted || generation != _generation) return;
      setState(() {
        _completed = completed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '設定を読み込めませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _complete() async {
    if (_saving || _loading || _completed != false) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.completeOnboarding();
      if (!mounted || generation != _generation) return;
      setState(() {
        _saving = false;
        _completed = true;
        _showTip = true;
      });
      _dismiss.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _saving = false;
        _error = '説明の確認状態を保存できませんでした。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: '設定を読み込み中'),
        ),
      );
    }
    if (_completed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('起動時の設定確認')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? '設定を確認できません。'),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      );
    }
    final onboarding = OnboardingScreen(
      key: _onboardingKey,
      onFinish: _complete,
      reminderService: widget.reminderService,
      reminderStore: widget.reminderStore,
      requestCameraPermission: widget.requestCameraPermission,
      isSaving: _saving,
      saveError: _error,
    );
    if (_completed == true) {
      final home = widget.homeBuilder(context);
      final closing = _dismiss.isAnimating;
      if (!_showTip && !closing) return home;
      return Stack(
        fit: StackFit.expand,
        children: [
          home,
          if (closing)
            SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(0, 1))
                  .animate(
                    CurvedAnimation(
                      parent: _dismiss,
                      curve: Curves.easeInCubic,
                    ),
                  ),
              child: IgnorePointer(child: onboarding),
            )
          else
            Positioned.fill(
              child: _FirstTip(onClose: () => setState(() => _showTip = false)),
            ),
        ],
      );
    }
    return onboarding;
  }
}

/// 1-8。初回設定の直後に、カメラボタンの場所を一度だけ案内する。
/// 表示中は画面全体を暗くして操作を止め、×で閉じると元に戻る。
class _FirstTip extends StatelessWidget {
  const _FirstTip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // CameraTabBar：下端の余白（最低12）＋高さ80。その少し上に吹き出しの先を置く。
    final barTop = math.max(MediaQuery.paddingOf(context).bottom, 12.0) + 80;
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(
            color: const Color(0x8C000000),
            onDismiss: onClose,
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: barTop + 2,
          child: AsakaoReveal(
            delay: const Duration(milliseconds: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AsakaoCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '毎朝のチェックはここから',
                              style: TextStyle(
                                fontFamily: AsakaoStyle.displayFont,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AsakaoStyle.ink,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '下のカメラボタンを押すと15秒の計測が始まります。',
                              style: AsakaoStyle.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '閉じる',
                        onPressed: onClose,
                        icon: const Icon(Icons.close, color: AsakaoStyle.muted),
                      ),
                    ],
                  ),
                ),
                // 吹き出しのしっぽ。真下のカメラボタンを指す。
                const CustomPaint(size: Size(28, 14), painter: _TailPainter()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tail = Path()
      ..moveTo(0, -1)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, -1)
      ..close();
    canvas.drawPath(tail, Paint()..color = AsakaoStyle.card);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
