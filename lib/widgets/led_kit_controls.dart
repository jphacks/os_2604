import 'package:flutter/material.dart';

import '../services/device/led_notification_service.dart';
import '../services/device/led_transport.dart';
import 'environment_view.dart';

class LedKitStatus extends StatelessWidget {
  const LedKitStatus({super.key, required this.service});
  final LedNotificationService service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (service.bluetooth) {
          BluetoothAvailability.poweredOff => 'Bluetoothがオフです。設定から有効にしてください。',
          BluetoothAvailability.denied => 'Bluetoothが許可されていません。設定アプリから許可できます。',
          BluetoothAvailability.unsupported => 'この環境ではキット接続を利用できません。',
          _ => switch (service.connection) {
            LedConnection.disconnected => 'キット未接続',
            LedConnection.connecting => 'キット接続準備中…',
            LedConnection.unsupported => 'この機器はLED通知に対応していません。',
            LedConnection.ready => 'キット接続済み',
          },
        }),
        Text(switch (service.delivery) {
          LedDelivery.idle => 'LEDは記録の保存完了を通知します。健康状態は示しません。',
          LedDelivery.sending => '点灯指示を送信中…',
          LedDelivery.sent => '点灯指示を送信しました（実点灯は未確認）',
          LedDelivery.failed =>
            'LED指示を送信できませんでした。記録の保存には影響しません。実際のLED状態は未確認です。',
          LedDelivery.skipped => 'LED通知を送信していません（未接続または連動オフ）。',
          LedDelivery.offSent => '消灯指示を送信しました（実消灯は未確認）',
        }),
      ],
    ),
  );
}

class LedKitControls extends StatefulWidget {
  const LedKitControls({super.key, required this.service});
  final LedNotificationService service;

  @override
  State<LedKitControls> createState() => _LedKitControlsState();
}

class _LedKitControlsState extends State<LedKitControls> {
  @override
  void initState() {
    super.initState();
    widget.service.initialize();
  }

  @override
  void dispose() {
    widget.service.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final s = widget.service;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '外部キットの接続とLED通知',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LedKitStatus(service: s),
          const Text('iPhone用デモ機能です。画像・測定値・記録IDは送信しません。'),
          OutlinedButton(
            onPressed:
                s.bluetooth == BluetoothAvailability.ready &&
                    s.connection != LedConnection.connecting &&
                    !s.ready
                ? (s.scanning ? s.stopScan : s.startScan)
                : null,
            child: Text(s.scanning ? '検索を停止' : 'キットを検索'),
          ),
          if (s.discoveryMessage != null) Text(s.discoveryMessage!),
          if (!s.ready && s.connection != LedConnection.connecting)
            for (final kit in s.kits)
              ListTile(
                title: Text(kit.name.isEmpty ? '名前なし' : kit.name),
                subtitle: Text(kit.id),
                trailing: const Icon(Icons.bluetooth),
                onTap: () => s.connect(kit),
              ),
          if (s.scanning) const Text('対象を選んでください。同名の機器も自動選択しません。'),
          if (s.connection == LedConnection.connecting || s.ready)
            TextButton(onPressed: s.disconnect, child: const Text('キットを切断')),
          if (s.ready) ...[
            Text('選択した機器：${s.selected?.name ?? ''}'),
            OutlinedButton(
              onPressed: s.delivery == LedDelivery.sending ? null : s.testLed,
              child: const Text('LEDをテスト（約3秒）'),
            ),
            TextButton(onPressed: s.turnOff, child: const Text('消灯指示を送信')),
            const Text('実物の点灯・消灯を目で確認してから連動を有効にしてください。切断時は連動がオフに戻ります。'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('実物を確認済み：計測の保存完了と連動'),
              value: s.automatic,
              onChanged: s.testSent ? s.enableAutomatic : null,
            ),
          ],
          LiveEnvironmentView(service: s, controls: true),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
