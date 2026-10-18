import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/settings_screen.dart';
import 'package:os_2604/services/db/app_database.dart';
import 'package:os_2604/services/db/health_record_repository.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';
import 'package:os_2604/services/settings/feedback_settings_store.dart';
import 'package:os_2604/services/settings/scan_mode_store.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/ui/asakao_style.dart';
import 'package:os_2604/ui/asakao_widgets.dart';

import '../support/fake_led_transport.dart';
import '../support/fake_reminder.dart';

class _FeedbackStore implements FeedbackSettingsStore {
  FeedbackSettings value = const FeedbackSettings();
  @override
  Future<FeedbackSettings> load() async => value;
  @override
  Future<void> save(FeedbackSettings settings) async => value = settings;
}

class _ModeStore implements ScanModeStore {
  _ModeStore(this.research);
  bool research;
  @override
  Future<bool> loadResearchMode() async => research;
  @override
  Future<void> saveResearchMode(bool enabled) async => research = enabled;
}

void main() {
  late AppDatabase db;
  late _FeedbackStore feedback;
  late _ModeStore mode;
  late FakeLedTransport transport;
  late LedNotificationService led;
  late FakeReminderStore reminderStore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    feedback = _FeedbackStore();
    mode = _ModeStore(false);
    transport = FakeLedTransport();
    led = LedNotificationService(transport);
    reminderStore = FakeReminderStore();
  });
  tearDown(() async {
    SoundEffects.settings = const FeedbackSettings();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: asakaoTheme(),
        home: SettingsScreen(
          repository: HealthRecordRepository(db),
          reminderService: FakeReminderService(),
          reminderStore: reminderStore,
          feedbackStore: feedback,
          scanModeStore: mode,
          ledService: led,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 画面を外し、サービスを片付ける（drift / ストリームのタイマーを残さない）。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    led.dispose();
    await tester.pump();
  }

  Finder row(String title) => find.widgetWithText(AsakaoListRow, title);
  Finder inRow(String title, String text) =>
      find.descendant(of: row(title), matching: find.text(text));
  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('subpage-back')));
    await tester.pumpAndSettle();
  }

  testWidgets('sections and rows appear in the designed order, as bands', (
    tester,
  ) async {
    await pump(tester);
    const order = [
      '毎日の記録',
      '毎朝の通知',
      '計測',
      '効果音',
      '振動',
      '計測中の音',
      '研究モード',
      '効果音は、端末が消音モードのときは鳴りません。',
      '外部キット（デモ）',
      'キットとLED通知・環境情報',
      '情報',
      'アプリの説明',
      'このアプリについて',
      'データ',
      '記録をすべて削除',
      '画像は保存されません。記録はこの端末の中だけにあります。',
    ];
    final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(
        ys[i],
        greaterThan(ys[i - 1]),
        reason: '${order[i]} は ${order[i - 1]} の下',
      );
    }
    // 角丸のカードではなく、画面の左右いっぱいのバンド。
    for (final group in tester.widgetList(find.byType(AsakaoListGroup))) {
      expect(
        group,
        isA<AsakaoListGroup>().having((g) => g.fullBleed, 'fullBleed', isTrue),
      );
    }
    expect(tester.getSize(find.byType(AsakaoListGroup).first).width, 800);
    // 現在の値を行に出す。
    expect(inRow('毎朝の通知', 'オフ'), findsOneWidget);
    expect(inRow('計測中の音', '木琴'), findsOneWidget);
    expect(inRow('研究モード', 'オフ'), findsOneWidget);
    expect(find.text('心拍数の実験的な推定'), findsOneWidget);
    expect(inRow('キットとLED通知・環境情報', '未接続'), findsOneWidget);
    expect(find.text('室温・湿度の取得もここから'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rows are at least 52 tall (60 with a subtitle)', (tester) async {
    await pump(tester);
    expect(tester.getSize(row('毎朝の通知')).height, greaterThanOrEqualTo(52));
    expect(tester.getSize(row('研究モード')).height, greaterThanOrEqualTo(60));
    expect(
      tester.getSize(row('キットとLED通知・環境情報')).height,
      greaterThanOrEqualTo(60),
    );
    await unmount(tester);
  });

  testWidgets('bands grow instead of clipping at 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(row('キットとLED通知・環境情報')).height, greaterThan(60));
    await unmount(tester);
  });

  testWidgets('research row shows the saved state and opens a working page', (
    tester,
  ) async {
    mode.research = true;
    await pump(tester);
    expect(inRow('研究モード', 'オン'), findsOneWidget);

    await tester.tap(row('研究モード'));
    await tester.pumpAndSettle();
    expect(find.text('実験的な機能'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(mode.research, isFalse); // 保存された
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await back(tester);
    expect(inRow('研究モード', 'オフ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sound, vibration and instrument rows keep working', (
    tester,
  ) async {
    SoundEffects.debugOnNote = (_, _) {};
    addTearDown(() => SoundEffects.debugOnNote = null);
    await pump(tester);
    Finder toggle(String t) => find.descendant(
      of: find.widgetWithText(AsakaoSwitchRow, t),
      matching: find.byType(Switch),
    );
    await tester.tap(toggle('振動'));
    await tester.pumpAndSettle();
    expect(feedback.value.haptics, isFalse);
    expect(tester.widget<Switch>(toggle('振動')).value, isFalse);

    await tester.tap(row('計測中の音'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('instrument-koto')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(feedback.value.instrument, MeasureInstrument.koto);
    expect(inRow('計測中の音', '琴'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kit row follows the connection and opens the kit page', (
    tester,
  ) async {
    await pump(tester);
    expect(inRow('キットとLED通知・環境情報', '未接続'), findsOneWidget);

    await tester.tap(row('キットとLED通知・環境情報'));
    await tester.pumpAndSettle();
    expect(find.text('外部キット'), findsOneWidget);
    expect(find.text('iPhone用のデモ機能です。画像・測定値・記録IDは送信しません。'), findsOneWidget);
    expect(find.text('キット接続後に選べます'), findsOneWidget);

    transport.status.add(BluetoothAvailability.ready);
    await tester.pump();
    await tester.tap(find.text('キットを検索'));
    transport.devices.add(const LedKit('a', 'Demo Kit'));
    await tester.pump();
    await tester.tap(find.text('Demo Kit'));
    await tester.pump();
    transport.links.last.add(KitLink.connected);
    await tester.pumpAndSettle();
    expect(led.ready, isTrue);
    expect(find.text('接続済み'), findsOneWidget);

    await back(tester);
    expect(tester.takeException(), isNull);
    expect(inRow('キットとLED通知・環境情報', '接続済み'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('delete all still asks before deleting', (tester) async {
    await pump(tester);
    await tester.tap(find.text('記録をすべて削除'));
    await tester.pumpAndSettle();
    expect(find.text('すべての記録を削除しますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('記録をすべて削除しました'), findsNothing);
    await unmount(tester);
  });
}
