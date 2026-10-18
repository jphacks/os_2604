import 'package:flutter/material.dart';

import '../models/environment_snapshot.dart';
import '../services/db/environment_record_repository.dart';
import '../services/device/environment_save_service.dart';
import '../services/device/led_notification_service.dart';

String environmentReason(EnvironmentState state) => switch (state) {
  EnvironmentState.available => '更新中',
  EnvironmentState.disabled => '環境情報の取得はオフです',
  EnvironmentState.disconnected => 'キット未接続、または前景で再接続が必要です',
  EnvironmentState.unsupported => 'このキットのファームウェアは環境情報に未対応です',
  EnvironmentState.initializing => 'センサーを準備しています',
  EnvironmentState.sensorError => 'センサーから取得できませんでした',
  EnvironmentState.outOfRange => 'センサーの対応範囲外です',
  EnvironmentState.stale => '更新が停止しています',
  EnvironmentState.readFailed => '環境情報を読み取れませんでした',
};

class EnvironmentValues extends StatelessWidget {
  const EnvironmentValues({
    super.key,
    required this.snapshot,
    this.historical = false,
  });
  final EnvironmentSnapshot snapshot;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    final t = snapshot.ambientTemperatureC;
    final h = snapshot.relativeHumidityPct;
    final received = snapshot.receivedAt?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          historical ? '計測時に保存したキット付近の環境' : 'キット付近の環境',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('キット付近の室温：${t == null ? '未測定' : '${t.toStringAsFixed(1)} ℃'}'),
        Text('キット付近の相対湿度：${h == null ? '未測定' : '${h.toStringAsFixed(1)} %RH'}'),
        if (snapshot.state != EnvironmentState.available || !historical)
          Text(environmentReason(snapshot.state)),
        if (received != null) ...[
          const Text('取得元：E84キットのSHT40'),
          Text('iPhone受信日時：$received'),
        ],
        if (historical && snapshot.state == EnvironmentState.available)
          const Text('計測終了時点の直近1サンプルです。15秒間の平均ではありません。'),
      ],
    );
  }
}

class LiveEnvironmentView extends StatelessWidget {
  const LiveEnvironmentView({super.key, required this.service});
  final LedNotificationService service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [EnvironmentValues(snapshot: service.snapshotEnvironment())],
    ),
  );
}

class SavedEnvironmentView extends StatefulWidget {
  const SavedEnvironmentView({
    super.key,
    required this.recordId,
    required this.store,
    required this.saves,
  });
  final String recordId;
  final EnvironmentRecordStore store;
  final EnvironmentSaveService saves;
  @override
  State<SavedEnvironmentView> createState() => _SavedEnvironmentViewState();
}

class _SavedEnvironmentViewState extends State<SavedEnvironmentView> {
  late Stream<EnvironmentSnapshot?> _stream = widget.store.watch(
    widget.recordId,
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.saves,
    builder: (context, _) => StreamBuilder<EnvironmentSnapshot?>(
      stream: _stream,
      builder: (context, snapshot) {
        final state = widget.saves.stateFor(widget.recordId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.hasError) ...[
              const Text('環境情報を読み込めませんでした。'),
              TextButton(
                onPressed: () => setState(
                  () => _stream = widget.store.watch(widget.recordId),
                ),
                child: const Text('環境情報を再読み込み'),
              ),
            ] else if (snapshot.data case final environment?)
              EnvironmentValues(snapshot: environment, historical: true)
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Text('環境情報を読み込んでいます…')
            else if (state != EnvironmentSaveState.saving &&
                state != EnvironmentSaveState.failed)
              const Text('環境情報の保存なし'),
            if (state == EnvironmentSaveState.saving)
              const Text('チェックは保存済みです。環境情報を保存しています…'),
            if (state == EnvironmentSaveState.failed) ...[
              const Text('チェックは保存済みです。環境情報を保存できませんでした'),
              TextButton(
                onPressed: () => widget.saves.retry(widget.recordId),
                child: const Text('環境情報の保存を再試行'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
