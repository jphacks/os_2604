import 'package:flutter/material.dart';

import '../screens/onboarding_screen.dart';
import '../services/settings/onboarding_store.dart';

/// Waits for durable acknowledgement before entering the home screen.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.store,
    required this.homeBuilder,
  });

  final OnboardingStore store;
  final WidgetBuilder homeBuilder;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _completed;
  bool _loading = false;
  bool _saving = false;
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
    if (_completed == true) return widget.homeBuilder(context);
    return OnboardingScreen(
      onContinue: _complete,
      isSaving: _saving,
      saveError: _error,
    );
  }
}
