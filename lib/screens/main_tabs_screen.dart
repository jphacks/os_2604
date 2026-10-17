import 'package:flutter/material.dart';

import '../services/db/health_record_repository.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';
import '../widgets/camera_tab_bar.dart';
import '../ui/asakao_style.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// タブ切替は経路を積まず、各画面のスクロール位置や設定状態を保持する。
class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({
    super.key,
    required this.repository,
    required this.reminderService,
    required this.reminderStore,
    required this.onStartCheck,
    required this.onShowExplanation,
    this.now = DateTime.now,
  });

  final HealthRecordRepository repository;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;
  final VoidCallback onStartCheck;
  final VoidCallback onShowExplanation;
  final DateTime Function() now;

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selected = 1;

  void _select(int index) {
    if (_selected != index) setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _selected == 1
        ? const Color(0xFFFFFDFC)
        : _selected == 0
        ? AsakaoStyle.background
        : Theme.of(context).scaffoldBackgroundColor,
    body: IndexedStack(
      index: _selected,
      children: [
        HistoryScreen(
          store: widget.repository,
          now: widget.now,
          embedded: true,
          onStartCheck: widget.onStartCheck,
        ),
        HomeScreen(
          repository: widget.repository,
          now: widget.now,
          showTabBar: false,
          onStartCheck: widget.onStartCheck,
          onOpenHistory: () => _select(0),
          onOpenSettings: () => _select(2),
          onShowExplanation: widget.onShowExplanation,
        ),
        SettingsScreen(
          repository: widget.repository,
          reminderService: widget.reminderService,
          reminderStore: widget.reminderStore,
          embedded: true,
        ),
      ],
    ),
    bottomNavigationBar: CameraTabBar(
      selectedIndex: _selected,
      onHistory: () => _select(0),
      onCamera: () => _select(1),
      onSettings: () => _select(2),
    ),
  );
}
