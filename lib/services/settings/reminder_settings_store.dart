/// 毎朝の通知の設定。未保存のときは「オフ・8:00」。
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = 8,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// 通知設定の端末内保存。
abstract interface class ReminderSettingsStore {
  Future<ReminderSettings> load();

  Future<void> save(ReminderSettings settings);
}
