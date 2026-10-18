import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';
import 'package:os_2604/ui/asakao_widgets.dart';
import 'package:os_2604/widgets/led_kit_controls.dart';

import '../support/fake_led_transport.dart';

void main() {
  testWidgets(
    'manual test and explicit visual confirmation enable integration',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = FakeLedTransport();
      final service = LedNotificationService(transport);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LedKitControls(service: service),
            ),
          ),
        ),
      );
      transport.status.add(BluetoothAvailability.ready);
      await tester.pump();
      await tester.tap(find.text('キットを検索'));
      transport.devices.add(const LedKit('a', 'Find Me Target'));
      transport.devices.add(const LedKit('b', 'Find Me Target'));
      await tester.pump();
      expect(find.text('Find Me Target'), findsNWidgets(2));
      expect(transport.links, isEmpty);
      await tester.tap(find.text('Find Me Target').first);
      await tester.pump();
      transport.links.last.add(KitLink.connected);
      await tester.pumpAndSettle();
      expect(service.ready, isTrue);
      expect(find.text('接続済み'), findsOneWidget);
      expect(find.text('選択した機器：Find Me Target'), findsOneWidget);
      final linkRow = find.widgetWithText(
        AsakaoSwitchRow,
        '実物を確認済み：計測の保存完了と連動',
      );
      expect(tester.widget<AsakaoSwitchRow>(linkRow).onChanged, isNull);
      await tester.tap(find.text('LEDをテスト（約3秒）'));
      await tester.pump();
      expect(find.text('点灯指示を送信しました（実点灯は未確認）'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.ensureVisible(linkRow);
      await tester.tap(
        find.descendant(of: linkRow, matching: find.byType(Switch)),
      );
      await tester.pump();
      expect(service.automatic, isTrue);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied Bluetooth has guidance and no scan', (tester) async {
    final transport = FakeLedTransport();
    final service = LedNotificationService(transport);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LedKitControls(service: service)),
      ),
    );
    transport.status.add(BluetoothAvailability.denied);
    await tester.pump();
    expect(find.textContaining('設定アプリから許可できます'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    await tester.pump();
  });

  testWidgets('before connecting: LED link is disabled and values are 未測定', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeLedTransport();
    final service = LedNotificationService(transport);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LedKitControls(service: service)),
        ),
      ),
    );
    expect(find.text('未接続'), findsOneWidget);
    expect(find.text('iPhone用のデモ機能です。画像・測定値・記録IDは送信しません。'), findsOneWidget);
    expect(find.text('キット接続後に選べます'), findsOneWidget);
    expect(find.text('LEDをテスト（約3秒）'), findsNothing);
    final link = find.widgetWithText(AsakaoSwitchRow, '実物を確認済み：計測の保存完了と連動');
    expect(tester.widget<AsakaoSwitchRow>(link).onChanged, isNull);
    // 環境情報はオフ：値は未測定、理由を出す。LED連動とは別に切り替えられる。
    expect(find.text('未測定'), findsNWidgets(2));
    expect(find.text('環境情報の取得はオフです'), findsOneWidget);
    expect(find.text('環境情報はLED通知とは別に使えます。'), findsOneWidget);
    final env = find.widgetWithText(AsakaoSwitchRow, '環境情報を取得する');
    expect(tester.widget<AsakaoSwitchRow>(env).value, isFalse);
    await tester.tap(find.descendant(of: env, matching: find.byType(Switch)));
    await tester.pump();
    expect(service.environmentEnabled, isTrue);
    expect(tester.widget<AsakaoSwitchRow>(env).value, isTrue);
    expect(find.text('キット未接続、または前景で再接続が必要です'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    await tester.pump();
  });
}
