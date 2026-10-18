import 'package:flutter/material.dart';

import '../models/environment_snapshot.dart';
import '../services/db/environment_record_repository.dart';
import '../services/device/environment_save_service.dart';
import '../services/device/led_notification_service.dart';
import '../ui/asakao_record_widgets.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

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

/// 履歴詳細の「キット」カード。「この日の記録」と同じ作り（全幅・区切り線・行）で、
/// 今のキットの接続と、計測終了時に保存したキット付近の室温・湿度を並べる。
/// 保存中・保存の失敗・読み込みの失敗は、カードの中で知らせて再試行できる。
class KitRecordCard extends StatefulWidget {
  const KitRecordCard({
    super.key,
    required this.recordId,
    this.ledService,
    this.saves,
  });

  final String recordId;
  final LedNotificationService? ledService;
  final EnvironmentSaveService? saves;

  @override
  State<KitRecordCard> createState() => _KitRecordCardState();
}

class _KitRecordCardState extends State<KitRecordCard> {
  late Stream<EnvironmentSnapshot?>? _stream = widget.saves?.store.watch(
    widget.recordId,
  );

  static Widget _row(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: child,
  );

  static Widget _note(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
    child: Text(text, style: AsakaoStyle.caption),
  );

  @override
  Widget build(BuildContext context) {
    final saves = widget.saves;
    final led = widget.ledService;
    return ListenableBuilder(
      listenable: Listenable.merge([?saves, ?led]),
      builder: (context, _) => StreamBuilder<EnvironmentSnapshot?>(
        stream: _stream,
        builder: (context, snapshot) {
          final env = snapshot.data;
          final state = saves?.stateFor(widget.recordId);
          final available = env?.state == EnvironmentState.available;
          String value(double? v, String unit, int digits) =>
              v == null ? '未測定' : '${v.toStringAsFixed(digits)} $unit';
          final subtitle = env == null || available
              ? 'キット付近・計測終了時'
              : environmentReason(env.state);
          final received = env?.receivedAt?.toLocal();
          final rows = <Widget>[
            if (led != null)
              _row(
                RecordRow(
                  title: 'キットの接続',
                  subtitle: '今の状態',
                  value: led.ready ? '接続中' : '未接続',
                ),
              ),
            if (saves != null) ...[
              _row(
                RecordRow(
                  title: '室温',
                  subtitle: subtitle,
                  value: value(env?.ambientTemperatureC, '℃', 1),
                ),
              ),
              _row(
                RecordRow(
                  title: '湿度',
                  subtitle: subtitle,
                  value: value(env?.relativeHumidityPct, '%RH', 1),
                ),
              ),
            ],
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AsakaoCard(
                padding: EdgeInsets.zero,
                fullBleed: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) const Divider(),
                      row,
                    ],
                    if (snapshot.hasError) ...[
                      const Divider(),
                      _row(
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '環境情報を読み込めませんでした。',
                                style: AsakaoStyle.caption,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _stream = saves?.store.watch(
                                  widget.recordId,
                                ),
                              ),
                              child: const Text('環境情報を再読み込み'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (state == EnvironmentSaveState.failed) ...[
                      const Divider(),
                      _row(
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'チェックは保存済みです。環境情報を保存できませんでした',
                                style: AsakaoStyle.caption,
                              ),
                            ),
                            TextButton(
                              onPressed: () => saves?.retry(widget.recordId),
                              child: const Text('環境情報の保存を再試行'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (saves != null) ...[
                if (state == EnvironmentSaveState.saving)
                  _note('チェックは保存済みです。環境情報を保存しています…')
                else if (env == null &&
                    !snapshot.hasError &&
                    snapshot.connectionState != ConnectionState.waiting &&
                    state != EnvironmentSaveState.failed)
                  _note('環境情報の保存なし')
                else if (available)
                  _note(
                    '計測終了時点の直近1サンプルです（15秒間の平均ではありません）。'
                    '取得元：E84キットのSHT40'
                    '${received == null ? '' : '　受信：${received.month}/${received.day} ${received.hour}:${received.minute.toString().padLeft(2, '0')}'}',
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 結果画面の「今日の記録」に足す、この記録に保存した室温・相対湿度の行（区切り線つき）。
/// 値は [EnvironmentRecordStore] に保存済みのこの記録のスナップショットだけから出す。
/// 保存中・読み込み中は「取得中」、値が無い・取れていない・保存失敗は「未測定」。
class ResultEnvironmentRows extends StatefulWidget {
  const ResultEnvironmentRows({
    super.key,
    required this.recordId,
    required this.saves,
  });
  final String recordId;
  final EnvironmentSaveService saves;

  @override
  State<ResultEnvironmentRows> createState() => _ResultEnvironmentRowsState();
}

class _ResultEnvironmentRowsState extends State<ResultEnvironmentRows> {
  late final Stream<EnvironmentSnapshot?> _stream = widget.saves.store.watch(
    widget.recordId,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.saves,
    builder: (context, _) => StreamBuilder<EnvironmentSnapshot?>(
      stream: _stream,
      builder: (context, snapshot) {
        final env = snapshot.data;
        final saving =
            widget.saves.stateFor(widget.recordId) ==
            EnvironmentSaveState.saving;
        final pending =
            env == null &&
            !snapshot.hasError &&
            (saving || snapshot.connectionState == ConnectionState.waiting);
        final available = env?.state == EnvironmentState.available;
        final t = available ? env?.ambientTemperatureC : null;
        final h = available ? env?.relativeHumidityPct : null;
        final subtitle = available
            ? 'キット（研究モード）'
            : pending
            ? 'キットから保存しています'
            : env != null
            ? environmentReason(env.state)
            : widget.saves.stateFor(widget.recordId) ==
                  EnvironmentSaveState.failed
            ? '環境情報を保存できませんでした'
            : 'キットの環境情報なし';
        String value(String? v) => pending ? '取得中' : v ?? '未測定';
        return Column(
          children: [
            const Divider(),
            RecordRow(
              title: '室温',
              subtitle: subtitle,
              value: value(t == null ? null : '${t.toStringAsFixed(1)}℃'),
            ),
            const Divider(),
            RecordRow(
              title: '相対湿度',
              subtitle: subtitle,
              value: value(h == null ? null : '${h.round()}%'),
            ),
          ],
        );
      },
    ),
  );
}
