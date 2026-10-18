import '../services/device/led_notification_service.dart';

import 'package:flutter/material.dart';

import '../services/db/health_record_repository.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';
import '../services/settings/scan_mode_store.dart';
import '../widgets/camera_tab_bar.dart';
import '../ui/asakao_style.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// 履歴・設定のタブ。切替は経路を積まず左右にスライドし、各画面のスクロール位置や設定状態を保持する。
/// 中央のカメラボタンはタブではなく、計測（3-1'）を cover で開く。
class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({
    super.key,
    this.ledService,
    required this.repository,
    required this.reminderService,
    required this.reminderStore,
    this.scanModeStore,
    required this.onStartCheck,
    this.now = DateTime.now,
  });

  final LedNotificationService? ledService;
  final HealthRecordRepository repository;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;
  final ScanModeStore? scanModeStore;

  /// 計測を開き、計測の流れ（cover）が閉じたら完了する。
  final Future<void> Function() onStartCheck;
  final DateTime Function() now;

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with SingleTickerProviderStateMixin {
  // CameraTabBar の番号に合わせる（0 = 履歴、2 = 設定）。
  int _selected = 0;
  bool _checking = false;

  /// 0 = 履歴、1 = 設定。履歴 → 設定は左へ、設定 → 履歴は右へスライドする。
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..addStatusListener((_) => setState(() {}));
  late final _curve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _curve.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
    index == 2 ? _slide.forward() : _slide.reverse();
  }

  /// 動いていない間、画面外のタブは操作・読み上げの対象から外す（状態は保つ）。
  Widget _tab({required bool settings, required Widget child}) {
    final hidden = !_slide.isAnimating && (settings != (_selected == 2));
    return Offstage(
      offstage: hidden,
      child: IgnorePointer(
        ignoring: settings != (_selected == 2),
        child: SlideTransition(
          position: Tween(
            begin: settings ? const Offset(1, 0) : Offset.zero,
            end: settings ? Offset.zero : const Offset(-1, 0),
          ).animate(_curve),
          child: child,
        ),
      ),
    );
  }

  /// 4-3 → 5-1。計測の流れが閉じたら履歴を見せる。
  Future<void> _startCheck() async {
    if (_checking) return; // 連打で計測画面を重ねない
    _checking = true;
    try {
      await widget.onStartCheck();
    } finally {
      _checking = false;
    }
    if (mounted) _select(0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _selected == 0
        ? AsakaoStyle.background
        : Theme.of(context).scaffoldBackgroundColor,
    body: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _tab(
            settings: false,
            child: HistoryScreen(
              store: widget.repository,
              now: widget.now,
              embedded: true,
              onStartCheck: _startCheck,
            ),
          ),
          _tab(
            settings: true,
            child: SettingsScreen(
              ledService: widget.ledService,
              scanModeStore: widget.scanModeStore,
              repository: widget.repository,
              reminderService: widget.reminderService,
              reminderStore: widget.reminderStore,
              embedded: true,
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: CameraTabBar(
      selectedIndex: _selected,
      onHistory: () => _select(0),
      onCamera: _startCheck,
      onSettings: () => _select(2),
    ),
  );
}
