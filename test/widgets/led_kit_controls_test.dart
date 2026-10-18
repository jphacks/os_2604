import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';
import 'package:os_2604/widgets/led_kit_controls.dart';

import '../support/fake_led_transport.dart';

void main() {
  testWidgets(
    'manual test and explicit visual confirmation enable integration',
    (tester) async {
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
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, '実物を確認済み：計測の保存完了と連動'),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('LEDをテスト（約3秒）'));
      await tester.pump();
      expect(find.text('点灯指示を送信しました（実点灯は未確認）'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, '実物を確認済み：計測の保存完了と連動'),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, '実物を確認済み：計測の保存完了と連動'),
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
}
