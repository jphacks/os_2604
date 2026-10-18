import 'package:flutter/material.dart';

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

class _OnboardingGateState extends State<OnboardingGate> {
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
    if (_completed == true) {
      final home = widget.homeBuilder(context);
      if (!_showTip) return home;
      return Stack(
        fit: StackFit.expand,
        children: [
          home,
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 100,
            child: _FirstTip(onClose: () => setState(() => _showTip = false)),
          ),
        ],
      );
    }
    return OnboardingScreen(
      onFinish: _complete,
      reminderService: widget.reminderService,
      reminderStore: widget.reminderStore,
      requestCameraPermission: widget.requestCameraPermission,
      isSaving: _saving,
      saveError: _error,
    );
  }
}

/// 1-8。初回設定の直後に、カメラボタンの場所を一度だけ案内する。
class _FirstTip extends StatelessWidget {
  const _FirstTip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => AsakaoCard(
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '毎朝のチェックはここから',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AsakaoStyle.ink,
                ),
              ),
              SizedBox(height: 4),
              Text('下のカメラボタンを押すと15秒の計測が始まります。', style: AsakaoStyle.caption),
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
  );
}
