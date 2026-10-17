import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/ai/template_record_summary.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_store.dart';
import '../widgets/manual_temperature_input.dart';
import '../widgets/self_condition_input.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.store, required this.result});
  final HealthRecordStore store;
  final HealthCheckResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late HealthCheckResult _saved = widget.result;
  late int? _condition = _saved.selfCondition;
  late double? _temperature = _saved.bodyTemperatureC;
  bool _validTemperature = true;
  bool _saving = false;
  String? _error;
  late Future<HistoryBaseline> _baseline = _loadBaseline();

  Future<HistoryBaseline> _loadBaseline() async => calculateHistoryBaseline(
    (await widget.store.loadAll()).map(
      (record) => (
        measuredAt: record.measuredAt,
        isValid: record.quality == MeasurementQuality.good,
        selfCondition: record.selfCondition,
      ),
    ),
    referenceDate: DateTime.now(),
  );

  Future<void> _save() async {
    if (_saving || !_validTemperature) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = HealthCheckResult(
        id: _saved.id,
        measuredAt: _saved.measuredAt,
        elapsed: _saved.elapsed,
        faceDetected: _saved.faceDetected,
        quality: _saved.quality,
        estimatedHeartRateBpm: _saved.estimatedHeartRateBpm,
        heartRateSource: _saved.heartRateSource,
        faceColorFeature: _saved.faceColorFeature,
        selfCondition: _condition,
        bodyTemperatureC: _temperature,
        temperatureSource: _temperature == null
            ? TemperatureSource.none
            : (_temperature == _saved.bodyTemperatureC
                  ? _saved.temperatureSource
                  : TemperatureSource.manual),
      );
      // The measurement was already committed before opening this screen.
      final report = HealthCheckResult(
        id: updated.id,
        measuredAt: updated.measuredAt,
        elapsed: updated.elapsed,
        faceDetected: updated.faceDetected,
        quality: updated.quality,
        estimatedHeartRateBpm: updated.estimatedHeartRateBpm,
        heartRateSource: updated.heartRateSource,
        faceColorFeature: updated.faceColorFeature,
        selfCondition: updated.selfCondition,
        bodyTemperatureC: updated.bodyTemperatureC,
        temperatureSource: updated.temperatureSource,
        reportText: const TemplateRecordSummary().format(updated),
        aiMode: ReportMode.template,
      );
      if (!await widget.store.updateInputsAndReport(report)) {
        throw StateError('Record has been removed.');
      }
      if (!mounted) return;
      setState(() {
        _saved = report;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('任意入力と定型レポートを保存しました')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '追記できませんでした。記録の削除や保存状態を確認して再試行してください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('測定結果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('測定日時：${formatRecordDate(_saved.measuredAt)}'),
            const Text('計測結果は端末に保存済みです。'),
            const Text('測定品質：良好'),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: _saving,
              child: Column(
                children: [
                  SelfConditionInput(
                    value: _condition,
                    onChanged: (value) => setState(() => _condition = value),
                  ),
                  const SizedBox(height: 16),
                  ManualTemperatureInput(
                    value: _temperature,
                    onChanged: (value) => setState(() => _temperature = value),
                    onValidityChanged: (value) =>
                        setState(() => _validTemperature = value),
                  ),
                ],
              ),
            ),
            if (_error != null) Text(_error!),
            if (_temperature != null && _temperature! <= 0)
              const Text('体温は0より大きい数値を入力するか、空欄にしてください。'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _saving ||
                      !_validTemperature ||
                      (_temperature != null && _temperature! <= 0)
                  ? null
                  : _save,
              child: Text(_saving ? '保存中…' : '任意入力とレポートを保存'),
            ),
            const SizedBox(height: 20),
            Text('保存済みの記録の振り返り', style: Theme.of(context).textTheme.titleLarge),
            const Text('端末内AIは未接続のため、定型レポートを表示します。'),
            const SizedBox(height: 8),
            Text(
              _saved.reportText ?? const TemplateRecordSummary().format(_saved),
            ),
            const SizedBox(height: 16),
            FutureBuilder<HistoryBaseline>(
              future: _baseline,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () =>
                        setState(() => _baseline = _loadBaseline()),
                    child: const Text('過去の記録を読み込めません。再試行'),
                  );
                }
                final baseline = snapshot.data;
                if (baseline == null) return const Text('過去の記録を確認中…');
                if (baseline.isAccumulating) return const Text('基準値蓄積中');
                return Text(
                  '今日を除く過去7日間の体調中央値：${baseline.selfConditionMedian} / 5',
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('このアプリは診断目的ではありません。体温は外部体温計の入力値です。'),
          ],
        ),
      ),
    ),
  );
}

String formatRecordDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
