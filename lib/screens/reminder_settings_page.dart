import 'package:flutter/material.dart';

import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// 毎朝の通知のオン・オフと時刻。予約に成功してから保存する。
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({
    super.key,
    required this.reminderService,
    required this.reminderStore,
  });

  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  ReminderSettings _reminder = const ReminderSettings();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await widget.reminderStore.load();
      if (mounted) setState(() => _reminder = loaded);
    } catch (_) {
      // 読めないときはオフとして表示する。
    }
  }

  /// 予約に成功してから保存する。失敗したら画面の状態も保存も変えない。
  Future<void> _apply(
    ReminderSettings next, {
    bool askPermission = false,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    var applied = false;
    try {
      if (askPermission && !await widget.reminderService.requestPermission()) {
        message = '通知が許可されていません。設定アプリから許可できます。';
      } else {
        if (next.enabled) {
          await widget.reminderService.scheduleDaily(next.hour, next.minute);
        } else {
          await widget.reminderService.cancel();
        }
        await widget.reminderStore.save(next);
        applied = true;
        message = next.enabled
            ? '毎朝 ${next.timeLabel} にお知らせします'
            : '毎朝の通知をオフにしました';
      }
    } catch (_) {
      message = '通知を設定できませんでした（設定は変更されていません）';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
      if (applied) _reminder = next;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked == null || !mounted) return;
    await _apply(_reminder.copyWith(hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('毎朝の通知')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsakaoListGroup(
            children: [
              SwitchListTile(
                title: const Text('毎朝の通知'),
                subtitle: const Text('決めた時刻に、記録をつけるお知らせを届けます'),
                value: _reminder.enabled,
                onChanged: _busy
                    ? null
                    : (on) => _apply(
                        _reminder.copyWith(enabled: on),
                        askPermission: on,
                      ),
              ),
              ListTile(
                title: const Text('通知時刻'),
                trailing: Text(_reminder.timeLabel),
                enabled: _reminder.enabled && !_busy,
                onTap: _pickTime,
              ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(_message!, style: AsakaoStyle.body),
            ),
        ],
      ),
    ),
  );
}
