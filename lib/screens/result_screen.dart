import 'package:flutter/material.dart';

import '../models/health_check_result.dart';
import '../services/ai/on_device_ai_client.dart';
import '../services/ai/on_device_ai_runner.dart';
import '../services/db/health_record_repository.dart';
import '../widgets/manual_temperature_input.dart';
import '../widgets/self_condition_input.dart';

/// 保存済みの記録を表示し、体調・体温を同一IDへ任意で追記する。
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.repository,
    required this.aiRunner,
    required this.recordId,
    required this.onBackToHome,
  });

  final HealthRecordRepository repository;

  /// アプリ共通の1つだけを受け取る。破棄は所有者（main）が行う。
  final OnDeviceAiRunner aiRunner;
  final String? recordId;
  final VoidCallback onBackToHome;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  HealthCheckResult? _record;
  bool _loading = true;
  bool _loadError = false;
  int? _condition;
  double? _temperature;
  bool _temperatureValid = true;
  String? _conditionMsg;
  String? _temperatureMsg;

  // 世代番号。新しい生成要求・体調/体温の保存・破棄で進め、古い結果を捨てる。
  int _gen = 0;
  bool _generating = false;
  String? _reportMsg;
  AiFallbackReason? _fallbackReason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _invalidateGeneration();
    super.dispose();
  }

  /// 実行中の生成結果を無効にする（書き込まない）。
  void _invalidateGeneration() {
    _gen++;
    if (_generating) {
      _generating = false;
      widget.aiRunner.cancel();
    }
  }

  Future<void> _generateReport() async {
    final id = widget.recordId;
    if (id == null || _generating) return;
    final gen = ++_gen;
    setState(() {
      _generating = true;
      _reportMsg = null;
    });
    String? failure;
    try {
      final fresh = await widget.repository.findById(id);
      if (!mounted || gen != _gen) return;
      if (fresh == null) throw StateError('record missing');
      final outcome = await widget.aiRunner.generateReflection(fresh);
      if (!mounted || gen != _gen) return;
      await widget.repository.updateReport(id, outcome.text, outcome.mode);
      if (!mounted || gen != _gen) return;
      final updated = await widget.repository.findById(id);
      if (!mounted || gen != _gen) return;
      setState(() {
        _record = updated;
        _fallbackReason = outcome.fallbackReason;
      });
    } catch (_) {
      failure = 'レポートを作成できませんでした（保存されていません）';
    }
    if (!mounted || gen != _gen) return;
    setState(() {
      _generating = false;
      _reportMsg = failure;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    final id = widget.recordId;
    try {
      final r = id == null ? null : await widget.repository.findById(id);
      if (!mounted) return;
      setState(() {
        _record = r;
        _condition = r?.selfCondition;
        _temperature = r?.bodyTemperatureC;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = true;
        _loading = false;
      });
    }
  }

  Future<void> _saveCondition() async {
    final c = _condition;
    if (c == null) return;
    _invalidateGeneration();
    try {
      await widget.repository.updateSelfCondition(widget.recordId!, c);
      if (!mounted) return;
      setState(() => _conditionMsg = '体調を保存しました');
    } catch (_) {
      if (!mounted) return;
      setState(() => _conditionMsg = '体調を保存できませんでした（保存されていません）');
    }
  }

  Future<void> _saveTemperature() async {
    final t = _temperature;
    if (t == null || !_temperatureValid) return;
    _invalidateGeneration();
    try {
      await widget.repository.updateTemperature(
        widget.recordId!,
        t,
        TemperatureSource.manual,
      );
      if (!mounted) return;
      setState(() => _temperatureMsg = '体温を保存しました');
    } catch (_) {
      if (!mounted) return;
      setState(() => _temperatureMsg = '体温を保存できませんでした（保存されていません）');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('結果')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final r = _record;
    if (_loadError || r == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_loadError ? '記録を読み込めませんでした。' : '該当する記録が見つかりません。'),
          const SizedBox(height: 16),
          if (_loadError)
            OutlinedButton(onPressed: _load, child: const Text('再読み込み')),
          FilledButton(
            onPressed: widget.onBackToHome,
            child: const Text('ホームへ'),
          ),
        ],
      );
    }
    final hr = r.estimatedHeartRateBpm;
    final showHr = hr != null && r.quality == MeasurementQuality.good;
    final t = r.bodyTemperatureC;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('記録は保存されました。'),
        const SizedBox(height: 16),
        _row('計測日時', _fmt(r.measuredAt)),
        _row(
          '計測時間',
          '${(r.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
        ),
        _row('品質', _quality(r.quality)),
        _row('顔検出', r.faceDetected ? 'あり' : 'なし'),
        _row('心拍数', showHr ? '${hr.round()} bpm' : '未測定'),
        if (showHr) const Text('心拍数は試験的な推定値です'),
        _row(
          '顔色特徴量',
          r.faceColorFeature == null ? '未測定' : '${r.faceColorFeature}',
        ),
        _row('体温', t == null ? '未測定' : '$t ℃（${_source(r.temperatureSource)}）'),
        const Text('体温はカメラで測定していません'),
        _row('体調', r.selfCondition == null ? '未測定' : '${r.selfCondition} / 5'),
        const SizedBox(height: 16),
        Text('レポート', style: Theme.of(context).textTheme.titleMedium),
        Text(r.reportText ?? 'レポートは未生成です。'),
        if (r.reportText != null) ...[
          Text(r.aiMode == ReportMode.onDevice ? '端末内AIで作成' : '定型文で作成'),
          if (r.aiMode == ReportMode.template && _fallbackReason != null)
            Text(_reasonText(_fallbackReason!)),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _generating ? null : _generateReport,
          child: Text(
            _generating
                ? 'レポートを作成しています…'
                : r.reportText == null
                ? 'レポートを作成'
                : 'レポートを作り直す',
          ),
        ),
        if (_reportMsg != null) Text(_reportMsg!),
        const Divider(height: 32),
        SelfConditionInput(
          value: _condition,
          onChanged: (v) => setState(() {
            _condition = v;
            _conditionMsg = null;
          }),
        ),
        OutlinedButton(
          onPressed: _condition == null ? null : _saveCondition,
          child: const Text('体調を保存'),
        ),
        if (_conditionMsg != null) Text(_conditionMsg!),
        const SizedBox(height: 24),
        ManualTemperatureInput(
          value: _temperature,
          onChanged: (v) => setState(() {
            _temperature = v;
            _temperatureMsg = null;
          }),
          onValidityChanged: (v) => setState(() => _temperatureValid = v),
        ),
        OutlinedButton(
          onPressed: _temperature == null || !_temperatureValid
              ? null
              : _saveTemperature,
          child: const Text('体温を保存'),
        ),
        if (_temperatureMsg != null) Text(_temperatureMsg!),
        const SizedBox(height: 24),
        const Text('このアプリは診断目的ではありません。', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: widget.onBackToHome, child: const Text('ホームへ')),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );

  static String _reasonText(AiFallbackReason r) => switch (r) {
    AiFallbackReason.disabled => '端末内AIがオフのため、定型文で表示しています',
    AiFallbackReason.modelNotReady ||
    AiFallbackReason.initializing => '端末内AIの準備ができていないため、定型文で表示しています',
    AiFallbackReason.timedOut => '作成に時間がかかったため、定型文で表示しています',
    AiFallbackReason.busy => '端末内AIが別の処理中のため、定型文で表示しています',
    AiFallbackReason.availabilityCheckFailed ||
    AiFallbackReason.generationFailed ||
    AiFallbackReason.invalidResponse => '端末内AIで作成できなかったため、定型文で表示しています',
    AiFallbackReason.invalidScan => '測定品質が十分でないため、定型文で表示しています',
    AiFallbackReason.unsupported ||
    AiFallbackReason.restricted ||
    AiFallbackReason.bridgeUnavailable ||
    AiFallbackReason.unavailable ||
    AiFallbackReason.cancelled ||
    AiFallbackReason.disposed => 'この端末では端末内AIを使えないため、定型文で表示しています',
  };

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _quality(MeasurementQuality q) => switch (q) {
    MeasurementQuality.good => '良好',
    MeasurementQuality.poor => '不十分',
    MeasurementQuality.interrupted => '中断',
  };

  static String _source(TemperatureSource s) => switch (s) {
    TemperatureSource.manual => '手入力',
    TemperatureSource.healthPlatform => 'ヘルスプラットフォーム',
    TemperatureSource.none => '出典なし',
  };
}
