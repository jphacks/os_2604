import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device/led_notification_service.dart';
import '../services/device/led_transport.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_subpage.dart';
import '../ui/asakao_widgets.dart';
import 'environment_view.dart';

/// 計測中・結果画面に出す、キットが「接続中」か「未接続」かだけの小さな表示。
class LedKitBadge extends StatelessWidget {
  const LedKitBadge({super.key, required this.service, this.dark = false});
  final LedNotificationService service;

  /// 暗い背景（計測画面）用の色にする。
  final bool dark;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final connected = service.ready;
      final dot = connected ? const Color(0xFF3DB27A) : const Color(0xFF9E9E9E);
      return Semantics(
        label: connected ? 'キット接続中' : 'キット未接続',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'キット接続中' : 'キット未接続',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? const Color(0xFFC9BDB5) : const Color(0xFF6E625B),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Bluetoothが使えないときの案内。使えるなら null。
String? ledBluetoothMessage(BluetoothAvailability bluetooth) =>
    switch (bluetooth) {
      BluetoothAvailability.poweredOff => 'Bluetoothがオフです。設定から有効にしてください。',
      BluetoothAvailability.denied => 'Bluetoothが許可されていません。設定アプリから許可できます。',
      BluetoothAvailability.unsupported => 'この環境ではキット接続を利用できません。',
      _ => null,
    };

/// LED指示の送信状況の説明。
String ledDeliveryMessage(LedDelivery delivery) => switch (delivery) {
  LedDelivery.idle => 'LEDは記録の保存完了を通知します。健康状態は示しません。',
  LedDelivery.sending => '点灯指示を送信中…',
  LedDelivery.sent => '点灯指示を送信しました（実点灯は未確認）',
  LedDelivery.failed => 'LED指示を送信できませんでした。記録の保存には影響しません。実際のLED状態は未確認です。',
  LedDelivery.skipped => 'LED通知を送信していません（未接続または連動オフ）。',
  LedDelivery.offSent => '消灯指示を送信しました（実消灯は未確認）',
};

class LedKitStatus extends StatelessWidget {
  const LedKitStatus({super.key, required this.service});
  final LedNotificationService service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (ledBluetoothMessage(service.bluetooth)) {
          final message? => message,
          _ => switch (service.connection) {
            LedConnection.disconnected => 'キット未接続',
            LedConnection.connecting => 'キット接続準備中…',
            LedConnection.unsupported => 'この機器はLED通知に対応していません。',
            LedConnection.ready => 'キット接続済み',
          },
        }),
        Text(ledDeliveryMessage(service.delivery)),
      ],
    ),
  );
}

/// 設定の「外部キット」ページ。
class KitSettingsPage extends StatelessWidget {
  const KitSettingsPage({super.key, required this.service});
  final LedNotificationService service;

  @override
  Widget build(BuildContext context) => AsakaoSubpage(
    title: '外部キット',
    children: [LedKitControls(service: service)],
  );
}

/// キットの接続・LED通知・環境情報の操作一式（バンド形式）。
/// 開いたときにBluetoothを初期化し、閉じるときに検索を止める。
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
    // 画面を外している最中に通知すると、ほかの画面（設定の行）が再描画できない。
    scheduleMicrotask(widget.service.stopScan);
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'iPhone用のデモ機能です。画像・測定値・記録IDは送信しません。',
              style: AsakaoStyle.caption,
            ),
          ),
          _statusBand(s),
          ..._discoveryNotes(s),
          const AsakaoSectionLabel('LED通知', padding: _sectionPadding),
          _ledBand(s),
          AsakaoCaption(ledDeliveryMessage(s.delivery)),
          if (s.ready)
            const AsakaoCaption(
              '実物の点灯・消灯を目で確認してから連動を有効にしてください。切断時は連動がオフに戻ります。',
            ),
          const AsakaoSectionLabel('キット付近の環境', padding: _sectionPadding),
          ..._environment(s),
        ],
      );
    },
  );

  static const _sectionPadding = EdgeInsets.fromLTRB(28, 24, 28, 4);

  bool _canSearch(LedNotificationService s) =>
      s.bluetooth == BluetoothAvailability.ready &&
      s.connection != LedConnection.connecting &&
      !s.ready;

  String _statusLabel(LedNotificationService s) =>
      ledBluetoothMessage(s.bluetooth) ??
      switch (s.connection) {
        LedConnection.disconnected => '未接続',
        LedConnection.connecting => '接続準備中…',
        LedConnection.unsupported => 'この機器はLED通知に対応していません。',
        LedConnection.ready => '接続済み',
      };

  Widget _statusBand(LedNotificationService s) {
    final choosing = !s.ready && s.connection != LedConnection.connecting;
    return AsakaoCard(
      padding: EdgeInsets.zero,
      fullBleed: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MergeSemantics(
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AsakaoStyle.neutralBackground,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(
                              Icons.bluetooth,
                              size: 22,
                              color: AsakaoStyle.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'キット',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AsakaoStyle.ink,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    right: 6,
                                  ),
                                  child: AsakaoStatusDot(on: s.ready),
                                ),
                                Expanded(
                                  child: Text(
                                    _statusLabel(s),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: AsakaoStyle.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (s.ready && s.selected != null)
                              Text(
                                '選択した機器：${s.selected!.name}',
                                style: AsakaoStyle.caption,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AsakaoStyle.coralInk,
                    side: const BorderSide(
                      color: AsakaoStyle.coral,
                      width: 1.5,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _canSearch(s)
                      ? (s.scanning ? s.stopScan : s.startScan)
                      : null,
                  child: Text(s.scanning ? '検索を停止' : 'キットを検索'),
                ),
              ],
            ),
          ),
          if (choosing)
            for (final kit in s.kits) ...[
              const Divider(),
              ListTile(
                minTileHeight: 52,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(kit.name.isEmpty ? '名前なし' : kit.name),
                subtitle: Text(kit.id),
                trailing: const Icon(Icons.bluetooth),
                onTap: () => s.connect(kit),
              ),
            ],
          if (s.connection == LedConnection.connecting || s.ready) ...[
            const Divider(),
            _ActionRow('キットを切断', s.disconnect),
          ],
        ],
      ),
    );
  }

  List<Widget> _discoveryNotes(LedNotificationService s) => [
    if (s.discoveryMessage != null) AsakaoCaption(s.discoveryMessage!),
    if (s.scanning) const AsakaoCaption('対象を選んでください。同名の機器も自動選択しません。'),
  ];

  Widget _ledBand(LedNotificationService s) => AsakaoCard(
    padding: EdgeInsets.zero,
    fullBleed: true,
    child: Column(
      children: [
        if (s.ready) ...[
          _ActionRow(
            'LEDをテスト（約3秒）',
            s.delivery == LedDelivery.sending ? null : s.testLed,
          ),
          const Divider(),
          _ActionRow('消灯指示を送信', s.turnOff),
          const Divider(),
        ],
        AsakaoSwitchRow(
          title: '実物を確認済み：計測の保存完了と連動',
          subtitle: !s.ready
              ? 'キット接続後に選べます'
              : s.automatic
              ? '記録の保存完了時に、点灯を指示します'
              : s.testSent
              ? '点灯を目で確認できたら、オンにしてください'
              : 'LEDをテストして実物を確認すると選べます',
          value: s.automatic,
          onChanged: s.testSent ? s.enableAutomatic : null,
        ),
      ],
    ),
  );

  List<Widget> _environment(LedNotificationService s) {
    final snapshot = s.snapshotEnvironment();
    final t = snapshot.ambientTemperatureC;
    final h = snapshot.relativeHumidityPct;
    final received = snapshot.receivedAt?.toLocal();
    return [
      AsakaoCard(
        padding: EdgeInsets.zero,
        fullBleed: true,
        child: Column(
          children: [
            AsakaoSwitchRow(
              title: '環境情報を取得する',
              subtitle: 'アプリを開いている間だけ取得',
              value: s.environmentEnabled,
              onChanged: s.enableEnvironment,
            ),
            const Divider(),
            _ValueRow('室温', t == null ? '未測定' : '${t.toStringAsFixed(1)} ℃'),
            const Divider(),
            _ValueRow(
              '相対湿度',
              h == null ? '未測定' : '${h.toStringAsFixed(1)} %RH',
            ),
          ],
        ),
      ),
      AsakaoCaption(environmentReason(snapshot.state)),
      if (received != null) ...[
        const AsakaoCaption('取得元：E84キットのSHT40'),
        AsakaoCaption('iPhone受信日時：$received'),
      ],
      const AsakaoCaption('環境情報はLED通知とは別に使えます。'),
    ];
  }
}

/// バンド内の操作行（文字だけ。押せないときは薄く表示）。
class _ActionRow extends StatelessWidget {
  const _ActionRow(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: onTap == null ? AsakaoStyle.muted : AsakaoStyle.link,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: AsakaoStyle.ink),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 15, color: AsakaoStyle.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
