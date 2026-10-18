import 'package:os_2604/services/notifications/daily_reminder_service.dart';
import 'package:os_2604/services/settings/reminder_settings_store.dart';

class FakeReminderService implements DailyReminderService {
  bool grant = true;
  bool failSchedule = false;
  int permissionRequests = 0;
  final List<(int, int)> scheduled = [];
  int cancels = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    if (failSchedule) throw StateError('schedule failed');
    scheduled.add((hour, minute));
  }

  @override
  Future<void> cancel() async => cancels++;

  /// 通知を押したことにする。
  void Function()? onOpen;

  @override
  Future<void> listenForOpen(void Function() onOpen) async =>
      this.onOpen = onOpen;
}

class FakeReminderStore implements ReminderSettingsStore {
  FakeReminderStore([this.value = const ReminderSettings()]);

  ReminderSettings value;
  int saves = 0;

  @override
  Future<ReminderSettings> load() async => value;

  @override
  Future<void> save(ReminderSettings settings) async {
    saves++;
    value = settings;
  }
}
