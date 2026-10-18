import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_store.dart';
import '../ui/asakao_record_widgets.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import 'history_screen.dart' show confirmRecordDeletion;

/// 履歴の1件の詳細。前後の記録へ移動でき、この記録を削除できる。
/// 履歴を新しい順に並べたとき、前（‹）は古い記録、次（›）は新しい記録。
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    super.key,
    required this.store,
    required this.recordId,
  });

  final HealthRecordStore store;
  final String? recordId;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late Stream<List<HealthCheckResult>> _records = widget.store.watchAll();
  late String? _id = widget.recordId;
  bool _deleting = false;

  Future<void> _delete(String id) async {
    if (_deleting) return;
    final confirmed = await confirmRecordDeletion(context, all: false);
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.store.deleteOne(id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除できませんでした。再試行してください。')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// その日（その記録の日付）より前7日・今日を除く有効記録から求めた、実際の基準値との差。
  /// 基準値がまだ無い（3件未満）か、体調が未入力なら null。
  double? _conditionDiff(
    HealthCheckResult record,
    List<HealthCheckResult> all,
  ) {
    final cond = record.selfCondition;
    if (cond == null) return null;
    final median = calculateHistoryBaseline([
      for (final r in all)
        (
          measuredAt: r.measuredAt,
          isValid: r.quality == MeasurementQuality.good,
          selfCondition: r.selfCondition,
        ),
    ], referenceDate: record.measuredAt).selfConditionMedian;
    return median == null ? null : cond - median;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<HealthCheckResult>>(
    stream: _records,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final List<HealthCheckResult> sorted = data == null
          ? const []
          : ([...data]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt)));
      final index = sorted.indexWhere((r) => r.id == _id);
      final record = index < 0 ? null : sorted[index];
      final older = index > 0 ? sorted[index - 1] : null;
      final newer = index >= 0 && index < sorted.length - 1
          ? sorted[index + 1]
          : null;
      return Scaffold(
        backgroundColor: AsakaoStyle.background,
        appBar: AppBar(
          // 戻るは iOS の標準に近い大きさ（矢印 32・文字 17）にする。
          leadingWidth: MediaQuery.textScalerOf(context).scale(120),
          leading: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 4, right: 12),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.chevron_left, size: 32),
              label: const Text('履歴'),
            ),
          ),
        ),
        body: SafeArea(
          child: snapshot.hasError
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _records = widget.store.watchAll()),
                    child: const Text('記録を読み込めません。再試行'),
                  ),
                )
              : data == null
              ? const Center(child: CircularProgressIndicator())
              : record == null
              ? const Center(
                  child: Text('該当する記録が見つかりません。', style: AsakaoStyle.body),
                )
              : _content(record, sorted, older: older, newer: newer),
        ),
      );
    },
  );

  // 「この日の記録」より下のカードは画面の左右いっぱいに広げ、角丸にしない。
  static final _dayButtonStyle = TextButton.styleFrom(
    backgroundColor: AsakaoStyle.coralPale,
    foregroundColor: AsakaoStyle.coralInk,
    disabledBackgroundColor: AsakaoStyle.neutralBackground,
    disabledForegroundColor: AsakaoStyle.muted,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    padding: EdgeInsets.zero,
    fixedSize: const Size(80, 48),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
  );

  static const _side = EdgeInsets.symmetric(horizontal: 24);
  static const _label = EdgeInsets.fromLTRB(28, 16, 28, 8);

  Widget _content(
    HealthCheckResult r,
    List<HealthCheckResult> all, {
    HealthCheckResult? older,
    HealthCheckResult? newer,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
    children: [
      Padding(
        padding: _side,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tooltip(
                  message: '古い記録',
                  child: TextButton(
                    onPressed: older == null
                        ? null
                        : () => setState(() => _id = older.id),
                    style: _dayButtonStyle,
                    child: SizedBox.expand(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text('前の日'),
                          const Positioned(
                            left: 2,
                            child: Icon(Icons.chevron_left, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      formatJaDate(r.measuredAt),
                      textAlign: TextAlign.center,
                      style: AsakaoStyle.title,
                    ),
                  ),
                ),
                Tooltip(
                  message: '新しい記録',
                  child: TextButton(
                    onPressed: newer == null
                        ? null
                        : () => setState(() => _id = newer.id),
                    style: _dayButtonStyle,
                    child: SizedBox.expand(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text('次の日'),
                          const Positioned(
                            right: 2,
                            child: Icon(Icons.chevron_right, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: Text(
                '${formatClock(r.measuredAt)} に記録',
                style: AsakaoStyle.caption,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      RecordQualityCard(r, fullBleed: true),
      const AsakaoSectionLabel('この日の記録', padding: _label),
      RecordValuesCard(
        r,
        conditionDiff: _conditionDiff(r, all),
        fullBleed: true,
      ),
      const AsakaoSectionLabel('この日のレポート', padding: _label),
      RecordReportCard(r, missingText: 'レポートは未作成です', fullBleed: true),
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Text(
          '医療機器ではありません。値は目安です。診断目的ではありません。体温はカメラでは測定していません。',
          style: AsakaoStyle.caption,
        ),
      ),
      const SizedBox(height: 24),
      AsakaoListGroup(
        fullBleed: true,
        children: [
          AsakaoListRow(
            title: 'この記録を削除',
            destructive: true,
            onTap: _deleting ? null : () => _delete(r.id),
          ),
        ],
      ),
    ],
  );
}
