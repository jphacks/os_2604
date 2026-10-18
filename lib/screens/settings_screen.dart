import 'package:flutter/material.dart';

import '../navigation/app_transitions.dart';
import '../services/db/health_record_repository.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/settings/reminder_settings_store.dart';
<<<<<<< HEAD
import '../services/device/led_notification_service.dart';
import '../widgets/led_kit_controls.dart';
=======
import '../services/settings/scan_mode_store.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import 'about_screen.dart';
import 'onboarding_screen.dart';
import 'reminder_settings_page.dart';
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834

/// 設定。毎朝の通知・このアプリについて・健康記録の全削除を提供する。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    this.embedded = false,
    required this.reminderService,
    required this.reminderStore,
<<<<<<< HEAD
    this.ledService,
=======
    this.scanModeStore,
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834
  });

  final bool embedded;
  final HealthRecordRepository repository;
  final DailyReminderService reminderService;
  final ReminderSettingsStore reminderStore;
<<<<<<< HEAD
  final LedNotificationService? ledService;
=======
  final ScanModeStore? scanModeStore;
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // デザイン 6-1：見出しの下と各グループの間を広めにとる。
  static const _firstSection = EdgeInsets.fromLTRB(20, 16, 20, 8);
  static const _section = EdgeInsets.fromLTRB(20, 28, 20, 8);

  bool _running = false;
  bool? _research;
  bool _savingMode = false;
  bool _modeLoadFailed = false;
  ReminderSettings _reminder = const ReminderSettings();

  @override
  void initState() {
    super.initState();
    _loadReminder();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final store = widget.scanModeStore;
    if (store == null) return;
    try {
      final research = await store.loadResearchMode();
      if (mounted) {
        setState(() {
          _research = research;
          _modeLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _modeLoadFailed = true);
    }
  }

  Future<void> _saveMode(bool research) async {
    if (_savingMode) return;
    setState(() => _savingMode = true);
    try {
      await widget.scanModeStore!.saveResearchMode(research);
      if (mounted) {
        setState(() {
          _research = research;
          _modeLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) _snack('計測モードを保存できませんでした（設定は変更されていません）');
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  Future<void> _loadReminder() async {
    try {
      final loaded = await widget.reminderStore.load();
      if (mounted) setState(() => _reminder = loaded);
    } catch (_) {
      // 読めないときはオフとして表示する。
    }
  }

<<<<<<< HEAD
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
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.ledService case final service?)
              LedKitControls(service: service),
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
=======
  Future<void> _openReminder() async {
    await Navigator.of(context).push<void>(
      AppTransitions.push(
        (_) => ReminderSettingsPage(
          reminderService: widget.reminderService,
          reminderStore: widget.reminderStore,
>>>>>>> ab3f11fbc9e26a8d46ab1af5eb2cb331f76cd834
        ),
      ),
    );
    if (mounted) await _loadReminder();
  }

  void _openAbout() =>
      Navigator.of(context)
          .push<void>(AppTransitions.push((_) => const AboutScreen()));

  /// 初回設定の説明（1-2・1-3）をもう一度見る。権限や通知の設定には触れない。
  void _openExplanation() => Navigator.of(context).push<void>(
    AppTransitions.push(
      (context) => OnboardingScreen(
        explanationOnly: true,
        onFinish: () => Navigator.of(context).pop(),
      ),
    ),
  );

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
    // 6-1 → 6-3 は sheet（半モーダル）。削除後のトースト（6-3'）は同じ画面に出す。
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AsakaoStyle.background,
      builder: (_) => const _DeleteConfirmSheet(),
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
    // 見出しは履歴タブと同じ AppBar・文字で、大きさと位置をそろえる。
    appBar: AppBar(
      title: const Text(
        '設定',
        key: ValueKey('settings-title'),
        style: AsakaoStyle.tabTitle,
      ),
      backgroundColor: AsakaoStyle.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      automaticallyImplyLeading: !widget.embedded,
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const AsakaoSectionLabel('通知', padding: _firstSection),
          // カードは画面の左右いっぱいに広げ、角丸にしない。
          AsakaoListGroup(
            fullBleed: true,
            children: [
              AsakaoListRow(
                title: '毎朝の通知',
                value: _reminder.enabled ? _reminder.timeLabel : 'オフ',
                onTap: _openReminder,
              ),
            ],
          ),
          if (widget.scanModeStore != null) ...[
            const AsakaoSectionLabel('計測', padding: _section),
            SwitchListTile(
              title: const Text('研究モード'),
              subtitle: const Text(
                'オフ：通常の記録。オン：心拍推定・顔色特徴量を試験的に取得します。診断には使用できません。次回の撮影から適用されます。',
              ),
              value: _research ?? false,
              onChanged: _research == null || _savingMode ? null : _saveMode,
            ),
            if (_modeLoadFailed) ...[
              const Text('計測モードを読み込めませんでした'),
              TextButton(
                onPressed: _loadMode,
                child: const Text('計測モードを再読み込み'),
              ),
            ],
          ],
          const AsakaoSectionLabel('情報', padding: _section),
          AsakaoListGroup(
            fullBleed: true,
            children: [
              AsakaoListRow(title: 'アプリの説明', onTap: _openExplanation),
              AsakaoListRow(title: 'このアプリについて', onTap: _openAbout),
            ],
          ),
          const AsakaoSectionLabel('データ', padding: _section),
          AsakaoCard(
            padding: EdgeInsets.zero,
            fullBleed: true,
            child: AsakaoListRow(
              title: '記録をすべて削除',
              destructive: true,
              onTap: _running ? null : _deleteAll,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
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
class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
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
                  fontFamily: AsakaoStyle.displayFont,
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
