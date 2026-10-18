import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/screens/onboarding_screen.dart';

import '../support/fake_reminder.dart';

void main() {
  late FakeReminderService reminder;
  late FakeReminderStore store;
  late int finished;

  setUp(() {
    reminder = FakeReminderService();
    store = FakeReminderStore();
    finished = 0;
  });

  Future<void> pumpFlow(
    WidgetTester tester, {
    Future<bool?> Function()? camera,
    bool explanationOnly = false,
    TextScaler? scaler,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: scaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: child!,
              ),
        home: OnboardingScreen(
          onFinish: () => finished++,
          reminderService: reminder,
          reminderStore: store,
          requestCameraPermission: camera ?? () async => true,
          explanationOnly: explanationOnly,
        ),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// スプラッシュ → 紹介 → データの扱い → カメラ説明まで進める。
  Future<void> toCameraPage(WidgetTester tester) async {
    await tapText(tester, 'タップしてはじめる');
    await tapText(tester, 'つづける');
    await tapText(tester, '同意してつづける');
    expect(find.text('カメラを使います'), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('happy path: every step, real states on the last page', (
    tester,
  ) async {
    await pumpFlow(tester);
    expect(find.text('あさかお'), findsOneWidget);
    await tapText(tester, 'タップしてはじめる');
    expect(find.textContaining('毎朝15秒で'), findsOneWidget);
    // 比較は「記録3件以上」の現行仕様。7日分の蓄積条件は示さない。
    expect(find.textContaining('3日分そろうと'), findsOneWidget);
    expect(find.textContaining('7日'), findsNothing);
    await tapText(tester, 'つづける');
    expect(find.text('画像は保存しません'), findsOneWidget);
    expect(find.text('記録はこの端末の中だけ'), findsOneWidget);
    expect(find.text('診断には使えません'), findsOneWidget);
    expect(find.textContaining('プライバシーポリシー'), findsNothing);
    await tapText(tester, '同意してつづける');
    await tapText(tester, 'カメラを許可する');
    expect(find.text('通知の時刻'), findsOneWidget);
    expect(reminder.permissionRequests, 0);
    await tapText(tester, '設定する');
    expect(reminder.permissionRequests, 1);
    expect(reminder.scheduled, [(8, 0)]);
    expect(store.value.enabled, isTrue);
    expect(find.text('準備ができました'), findsOneWidget);
    expect(find.text('カメラ：許可済み'), findsOneWidget);
    expect(find.text('通知：毎朝 8:00'), findsOneWidget);
    expect(finished, 0);
    await tapText(tester, '記録をはじめる');
    expect(finished, 1);
    await unmount(tester);
  });

  testWidgets('a changed time wheel value is what gets scheduled', (
    tester,
  ) async {
    await pumpFlow(tester);
    await toCameraPage(tester);
    await tapText(tester, '今はしない');
    // 1-4 → 1-5（fade）→ 1-6（push）
    await tapText(tester, 'あとで設定する');
    // 時間のホイールを1つ分ずらす。
    await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -32));
    await tester.pumpAndSettle();
    await tapText(tester, '設定する');
    expect(reminder.scheduled, hasLength(1));
    expect(reminder.scheduled.single.$1, isNot(8));
    expect(find.text('通知：毎朝 ${store.value.timeLabel}'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('camera denied shows steps, can continue, never blocks', (
    tester,
  ) async {
    await pumpFlow(tester, camera: () async => false);
    await toCameraPage(tester);
    await tapText(tester, 'カメラを許可する');
    expect(find.text('カメラがオフです'), findsOneWidget);
    expect(find.text('設定アプリでオンにする方法'), findsOneWidget);
    expect(find.text('設定アプリを開く'), findsNothing); // 開く手段が無い間は出さない
    await tapText(tester, 'あとで設定する');
    expect(find.text('通知の時刻'), findsOneWidget);
    await tapText(tester, 'スキップ');
    expect(find.text('カメラ：未許可'), findsOneWidget);
    expect(find.text('通知：オフ'), findsOneWidget);
    expect(reminder.scheduled, isEmpty);
    expect(store.saves, 0);
    await tapText(tester, '記録をはじめる');
    expect(finished, 1);
    await unmount(tester);
  });

  testWidgets('skipping the camera does not ask the OS', (tester) async {
    var asked = 0;
    await pumpFlow(
      tester,
      camera: () async {
        asked++;
        return true;
      },
    );
    await toCameraPage(tester);
    await tapText(tester, '今はしない');
    // 1-4 → 1-5（fade）→ 1-6（push）
    expect(find.text('カメラがオフです'), findsOneWidget);
    expect(find.text('カメラを使います'), findsNothing); // 置き換えで戻り先に残らない
    await tapText(tester, 'あとで設定する');
    expect(find.text('通知の時刻'), findsOneWidget);
    await tapText(tester, 'スキップ');
    expect(asked, 0);
    expect(find.text('カメラ：未許可'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('camera that cannot be pre-checked is deferred honestly', (
    tester,
  ) async {
    for (final camera in <Future<bool?> Function()>[
      () async => null,
      () async => throw StateError('no channel'),
    ]) {
      await pumpFlow(tester, camera: camera);
      await toCameraPage(tester);
      await tapText(tester, 'カメラを許可する');
      await tapText(tester, 'スキップ');
      expect(find.text('カメラ：最初の計測時に確認します'), findsOneWidget);
      expect(find.text('カメラ：許可済み'), findsNothing);
      await unmount(tester);
    }
  });

  testWidgets('notification skip saves nothing and reaches the last page', (
    tester,
  ) async {
    await pumpFlow(tester);
    await toCameraPage(tester);
    await tapText(tester, 'カメラを許可する');
    await tapText(tester, 'スキップ');
    expect(reminder.permissionRequests, 0);
    expect(store.saves, 0);
    expect(find.text('カメラ：許可済み'), findsOneWidget);
    expect(find.text('通知：オフ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('notification denied shows steps and continues without it', (
    tester,
  ) async {
    reminder.grant = false;
    await pumpFlow(tester);
    await toCameraPage(tester);
    await tapText(tester, 'カメラを許可する');
    await tapText(tester, '設定する');
    expect(find.text('通知がオフです'), findsOneWidget);
    expect(reminder.scheduled, isEmpty);
    expect(store.saves, 0);
    await tapText(tester, '通知なしで進む');
    expect(find.text('通知：オフ'), findsOneWidget);
    await tapText(tester, '記録をはじめる');
    expect(finished, 1);
    await unmount(tester);
  });

  testWidgets('scheduling failure is shown, saves nothing, skip still works', (
    tester,
  ) async {
    reminder.failSchedule = true;
    await pumpFlow(tester);
    await toCameraPage(tester);
    await tapText(tester, '今はしない');
    // 1-4 → 1-5（fade）→ 1-6（push）
    await tapText(tester, 'あとで設定する');
    await tapText(tester, '設定する');
    expect(find.textContaining('通知を設定できませんでした'), findsOneWidget);
    expect(find.text('通知の時刻'), findsOneWidget);
    expect(store.saves, 0);
    await tapText(tester, 'スキップ');
    expect(find.text('通知：オフ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('save failure after scheduling cancels the schedule', (
    tester,
  ) async {
    final failing = _FailingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onFinish: () {},
          reminderService: reminder,
          reminderStore: failing,
          requestCameraPermission: () async => true,
        ),
      ),
    );
    await toCameraPage(tester);
    await tapText(tester, '今はしない');
    // 1-4 → 1-5（fade）→ 1-6（push）
    await tapText(tester, 'あとで設定する');
    await tapText(tester, '設定する');
    expect(find.textContaining('通知を設定できませんでした'), findsOneWidget);
    expect(reminder.cancels, 1);
    await unmount(tester);
  });

  testWidgets('explanation-only mode shows the explanation and closes', (
    tester,
  ) async {
    var asked = 0;
    await pumpFlow(
      tester,
      explanationOnly: true,
      camera: () async {
        asked++;
        return true;
      },
    );
    expect(find.text('タップしてはじめる'), findsNothing);
    await tapText(tester, 'つづける');
    expect(find.text('診断には使えません'), findsOneWidget);
    await tapText(tester, '閉じる');
    expect(finished, 1);
    expect(asked, 0);
    expect(reminder.permissionRequests, 0);
    await unmount(tester);
  });

  testWidgets('small screen and large text still reach every button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpFlow(tester, scaler: const TextScaler.linear(2));
    await toCameraPage(tester);
    await tapText(tester, 'カメラを許可する');
    await tapText(tester, '設定する');
    await tapText(tester, '記録をはじめる');
    expect(finished, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}

class _FailingStore extends FakeReminderStore {
  @override
  Future<void> save(settings) async => throw StateError('disk full');
}
