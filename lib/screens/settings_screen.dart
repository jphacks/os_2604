import 'package:flutter/material.dart';

import '../services/db/health_record_repository.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';

/// 設定。毎朝の通知と健康記録の全削除を提供する。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    this.embedded = false,
    required this.reminderService,
    required this.reminderStore,
  });

  final bool embedded;
  final HealthRecordRepository repository;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _running = false;
  String? _message;
  ReminderSettings _reminder = const ReminderSettings();
  bool _reminderBusy = false;
  String? _reminderMessage;

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  Future<void> _loadReminder() async {
    try {
      final loaded = await widget.reminderStore.load();
      if (mounted) setState(() => _reminder = loaded);
    } catch (_) {
      // 読めないときはオフとして表示する。
    }
  }

  /// 予約に成功してから保存する。失敗したら画面の状態も保存も変えない。
  Future<void> _applyReminder(
    ReminderSettings next, {
    bool askPermission = false,
  }) async {
    setState(() {
      _reminderBusy = true;
      _reminderMessage = null;
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
            ? '毎朝 ${_formatTime(next)} にお知らせします'
            : '毎朝の通知をオフにしました';
      }
    } catch (_) {
      message = '通知を設定できませんでした（設定は変更されていません）';
    }
    if (!mounted) return;
    setState(() {
      _reminderBusy = false;
      _reminderMessage = message;
      if (applied) _reminder = next;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked == null || !mounted) return;
    await _applyReminder(
      _reminder.copyWith(hour: picked.hour, minute: picked.minute),
    );
  }

  static String _formatTime(ReminderSettings s) =>
      '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての健康記録を削除しますか？'),
        content: const Text('保存されている記録がすべて消え、元に戻せません。初回の説明の確認状態は残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _running = true;
      _message = null;
    });
    String message;
    try {
      await widget.repository.deleteAll();
      message = 'すべての健康記録を削除しました';
    } catch (_) {
      message = '削除できませんでした（記録は削除されていません）';
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('毎朝の通知'),
              subtitle: const Text('決めた時刻に、記録をつけるお知らせを届けます'),
              value: _reminder.enabled,
              onChanged: _reminderBusy
                  ? null
                  : (on) => _applyReminder(
                      _reminder.copyWith(enabled: on),
                      askPermission: on,
                    ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('通知時刻'),
              trailing: Text(_formatTime(_reminder)),
              enabled: _reminder.enabled && !_reminderBusy,
              onTap: _pickTime,
            ),
            if (_reminderMessage != null) Text(_reminderMessage!),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _running ? null : _deleteAll,
              child: const Text('すべての健康記録を削除'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 24),
            const Text('このアプリは診断目的ではありません', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
