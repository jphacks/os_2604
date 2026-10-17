import 'package:flutter/material.dart';

import '../services/db/health_record_repository.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import 'about_screen.dart';
import 'reminder_settings_page.dart';

/// 設定。毎朝の通知・このアプリについて・健康記録の全削除を提供する。
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
  ReminderSettings _reminder = const ReminderSettings();

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

  Future<void> _openReminder() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReminderSettingsPage(
          reminderService: widget.reminderService,
          reminderStore: widget.reminderStore,
        ),
      ),
    );
    if (mounted) await _loadReminder();
  }

  void _openAbout() =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const AboutScreen()));

  void _snack(String text, {bool ok = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AsakaoStyle.ink,
          content: Row(
            children: [
              if (ok) ...[
                const Icon(Icons.check, size: 18, color: AsakaoStyle.scanGreen),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteConfirmDialog(),
    );
    if (ok != true || !mounted) return;
    setState(() => _running = true);
    try {
      await widget.repository.deleteAll();
      if (mounted) _snack('記録をすべて削除しました', ok: true);
    } catch (_) {
      if (mounted) _snack('削除できませんでした（記録は削除されていません）');
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              '設定',
              key: ValueKey('settings-title'),
              style: AsakaoStyle.title,
            ),
          ),
          const AsakaoSectionLabel('通知'),
          AsakaoListGroup(
            children: [
              AsakaoListRow(
                title: '毎朝の通知',
                value: _reminder.enabled ? _reminder.timeLabel : 'オフ',
                onTap: _openReminder,
              ),
            ],
          ),
          const AsakaoSectionLabel('情報'),
          AsakaoListGroup(
            children: [AsakaoListRow(title: 'このアプリについて', onTap: _openAbout)],
          ),
          const AsakaoSectionLabel('データ'),
          AsakaoCard(
            padding: EdgeInsets.zero,
            child: AsakaoListRow(
              title: '記録をすべて削除',
              destructive: true,
              onTap: _running ? null : _deleteAll,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: AsakaoStyle.muted,
                  ),
                ),
                Expanded(
                  child: Text(
                    '画像は保存されません。記録はこの端末の中だけにあります。',
                    style: AsakaoStyle.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 6-3。削除の確認。
class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AsakaoStyle.background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AsakaoStyle.destructivePale,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.delete_outline,
                    color: AsakaoStyle.destructive,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'すべての記録を削除しますか？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AsakaoStyle.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'これまでの記録とレポートがこの端末から削除されます。この操作は取り消せません。',
                textAlign: TextAlign.center,
                style: AsakaoStyle.caption,
              ),
            ],
          ),
        ),
        const Divider(),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AsakaoStyle.destructive,
                    minimumSize: const Size.fromHeight(52),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('削除する'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
