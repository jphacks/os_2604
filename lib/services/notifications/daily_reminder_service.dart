import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../settings/reminder_settings_store.dart';

/// 毎朝の端末内通知。通知は1件だけで、設定し直すと前の予約を置き換える。
abstract interface class DailyReminderService {
  /// 通知の許可を求める。許可されたら true。例外は投げない。
  Future<bool> requestPermission();

  /// 毎日 [hour]:[minute] に通知する。失敗時は例外を投げる。
  Future<void> scheduleDaily(int hour, int minute);

  Future<void> cancel();
}

/// flutter_local_notifications による実装。通知にデータは載せない。
class LocalDailyReminderService implements DailyReminderService {
  LocalDailyReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String> Function()? localTimezone,
    this.now = DateTime.now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _localTimezone = localTimezone ?? _deviceTimezone;

  static const int notificationId = 1;
  static const String title = '15秒チェック';
  static const String body = 'おはようございます。今日の記録をつけましょう。';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _localTimezone;

  /// 次回時刻の計算に使う時計。テストでは固定する。
  final DateTime Function() now;
  bool _ready = false;

  static Future<String> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  /// 失敗したら次の呼び出しでやり直す。
  Future<void> _ensureReady() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _localTimezone()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 許可はオンにしたときだけ求める。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureReady();
      final granted = switch (defaultTargetPlatform) {
        TargetPlatform.iOS =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true),
        TargetPlatform.android =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission(),
        _ => false,
      };
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    await _ensureReady();
    final current = tz.TZDateTime.from(now(), tz.local);
    var next = tz.TZDateTime(
      tz.local,
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
    if (!next.isAfter(current)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '毎朝の通知',
          channelDescription: '毎朝、記録をつけるタイミングをお知らせします',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // 正確なアラーム権限を要求しない。Android では数分ずれることがある。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    await _ensureReady();
    await _plugin.cancel(id: notificationId);
  }
}

/// 起動時に保存済み設定を予約し直す（再インストール・タイムゾーン変更に備える）。
/// 失敗してもアプリの起動は止めない。
Future<void> restoreDailyReminder(
  ReminderSettingsStore store,
  DailyReminderService service,
) async {
  try {
    final s = await store.load();
    if (s.enabled) await service.scheduleDaily(s.hour, s.minute);
  } catch (_) {
    // 通知はなくてもアプリは使えるため、ここでは何もしない。
  }
}
