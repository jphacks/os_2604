import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/notifications/daily_reminder_service.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/fake_reminder.dart';

/// 通知プラグインの代役。呼び出しだけを記録する。
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  int initializes = 0;
  final List<({int id, tz.TZDateTime at, String? title, String? body})>
  scheduled = [];
  final List<int> cancelled = [];
  DateTimeComponents? lastMatch;
  AndroidScheduleMode? lastMode;
  String? lastPayload;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializes++;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add((id: id, at: scheduledDate, title: title, body: body));
    lastMatch = matchDateTimeComponents;
    lastMode = androidScheduleMode;
    lastPayload = payload;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePlugin plugin;
  late DateTime clock;
  late LocalDailyReminderService service;

  setUp(() {
    plugin = _FakePlugin();
    clock = DateTime.utc(2026, 10, 17, 9, 0);
    service = LocalDailyReminderService(
      plugin: plugin,
      localTimezone: () async => 'Asia/Tokyo',
      now: () => clock,
    );
  });

  test('schedules one fixed-id daily notification without a payload', () async {
    await service.scheduleDaily(8, 0);
    expect(plugin.scheduled, hasLength(1));
    final s = plugin.scheduled.single;
    expect(s.id, LocalDailyReminderService.notificationId);
    expect(s.title, '15秒チェック');
    expect(s.body, 'おはようございます。今日の記録をつけましょう。');
    expect(plugin.lastMatch, DateTimeComponents.time);
    expect(plugin.lastMode, AndroidScheduleMode.inexactAllowWhileIdle);
    expect(plugin.lastPayload, isNull);
  });

  test('picks the next occurrence in the device time zone', () async {
    // 18:00 JST（UTC 09:00）。08:00 は翌朝、21:00 は今夜。
    await service.scheduleDaily(8, 0);
    await service.scheduleDaily(21, 0);
    final morning = plugin.scheduled[0].at;
    final evening = plugin.scheduled[1].at;
    expect(morning.location.name, 'Asia/Tokyo');
    expect((morning.day, morning.hour, morning.minute), (18, 8, 0));
    expect((evening.day, evening.hour, evening.minute), (17, 21, 0));
  });

  test(
    'rescheduling reuses the same id, so the old reminder is replaced',
    () async {
      await service.scheduleDaily(8, 0);
      await service.scheduleDaily(7, 15);
      expect(plugin.scheduled.map((s) => s.id).toSet(), {
        LocalDailyReminderService.notificationId,
      });
      expect(plugin.scheduled.last.at.hour, 7);
      expect(plugin.scheduled.last.at.minute, 15);
      expect(plugin.initializes, 1);
    },
  );

  test('cancel removes the fixed id', () async {
    await service.cancel();
    expect(plugin.cancelled, [LocalDailyReminderService.notificationId]);
  });

  test('time zone lookup failure throws and retries next time', () async {
    var fail = true;
    final s = LocalDailyReminderService(
      plugin: plugin,
      localTimezone: () async {
        if (fail) throw StateError('no zone');
        return 'Asia/Tokyo';
      },
      now: () => clock,
    );
    await expectLater(s.scheduleDaily(8, 0), throwsStateError);
    expect(plugin.scheduled, isEmpty);
    fail = false;
    await s.scheduleDaily(8, 0);
    expect(plugin.scheduled, hasLength(1));
  });

  group('restoreDailyReminder', () {
    test('reschedules when enabled', () async {
      final fake = FakeReminderService();
      await restoreDailyReminder(
        FakeReminderStore(
          const ReminderSettings(enabled: true, hour: 6, minute: 5),
        ),
        fake,
      );
      expect(fake.scheduled, [(6, 5)]);
    });

    test('does nothing when disabled', () async {
      final fake = FakeReminderService();
      await restoreDailyReminder(FakeReminderStore(), fake);
      expect(fake.scheduled, isEmpty);
      expect(fake.cancels, 0);
    });

    test('swallows scheduling failure', () async {
      final fake = FakeReminderService()..failSchedule = true;
      await restoreDailyReminder(
        FakeReminderStore(const ReminderSettings(enabled: true)),
        fake,
      );
      expect(fake.scheduled, isEmpty);
    });
  });
}
