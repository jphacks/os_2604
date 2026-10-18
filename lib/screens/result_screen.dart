import 'package:flutter/material.dart';

import '../navigation/app_transitions.dart';
import '../models/health_check_result.dart';
import '../services/ai/on_device_ai_client.dart';
import '../services/ai/on_device_ai_runner.dart';
import '../services/ai/template_record_summary.dart';
import '../services/analysis/history_baseline.dart';
import '../services/db/health_record_repository.dart';
import '../services/sound/sound_effects.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_record_widgets.dart';
import '../ui/asakao_widgets.dart';
import '../ui/pachinko_effects.dart';
import '../widgets/manual_temperature_input.dart';
import '../widgets/self_condition_input.dart';
import '../services/device/environment_save_service.dart';
import '../services/device/led_notification_service.dart';
import '../widgets/led_kit_controls.dart';

/// 計測直後の自己申告（4-1）→ レポート生成（4-2）→ 結果（4-3）。
/// 記録は計測直後に保存済みで、ここでは同一IDへ体調・体温・レポートを追記する。
/// レポート済みの記録（履歴から開いた場合）は結果を直接表示する。
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.repository,
    required this.aiRunner,
    required this.recordId,
    required this.onBackToHome,
    this.ledService,
    this.environmentSaves,
  });

  final HealthRecordRepository repository;

  /// アプリ共通の1つだけを受け取る。破棄は所有者（main）が行う。
  final OnDeviceAiRunner aiRunner;
  final String? recordId;
  final VoidCallback onBackToHome;
  final LedNotificationService? ledService;
  final EnvironmentSaveService? environmentSaves;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

enum _Stage { input, generating, failed, result }

class _ResultScreenState extends State<ResultScreen> {
  HealthCheckResult? _record;
  HistoryBaseline? _baseline;
  bool _loading = true;
  bool _loadError = false;
  _Stage _stage = _Stage.input;

  // 入力（4-1）
  int? _condition;
  double? _temperature;
  bool _temperatureValid = true;
  bool _saving = false;
  String? _inputMsg;

  // 世代番号。新しい生成要求・破棄で進め、古い結果を捨てる。
  int _gen = 0;
  bool _generating = false;
  bool _wantTemplate = false; // 「定型文で先に見る」: AIを待たず定型文にする
  AiFallbackReason? _fallbackReason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// パチンコ風で計測を終えて来たときは、派手な背景と見出しにする（開いた時点で決める）。
  final bool _pachinko = SoundEffects.pachinkoFinish;

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

  /// 今日を除く直近7日の有効記録から基準値を求める。
  Future<(HealthCheckResult?, HistoryBaseline)> _freshAndBaseline(
    String id,
    DateTime measuredAt,
  ) async {
    final referenceAt = measuredAt.toLocal();
    final today = DateTime(
      referenceAt.year,
      referenceAt.month,
      referenceAt.day,
    );
    final start = DateTime(today.year, today.month, today.day - 7);
    final (fresh, observations) = await (
      widget.repository.findById(id),
      widget.repository.baselineObservations(start, today),
    ).wait;
    return (
      fresh,
      calculateHistoryBaseline(
        observations,
        referenceDate: fresh?.measuredAt ?? measuredAt,
      ),
    );
  }

  Future<void> _generateReport() async {
    final id = widget.recordId;
    if (id == null || _generating || _saving) return;
    final gen = ++_gen;
    setState(() {
      _generating = true;
      _stage = _Stage.generating;
    });
    try {
      final (fresh, baseline) = await _freshAndBaseline(
        id,
        _record?.measuredAt ?? DateTime.now(),
      );
      if (!mounted || gen != _gen) return;
      if (fresh == null) throw StateError('record missing');
      final ({String text, ReportMode mode, AiFallbackReason? reason}) outcome;
      if (_wantTemplate) {
        outcome = (
          text: const TemplateRecordSummary().format(fresh, baseline: baseline),
          mode: ReportMode.template,
          reason: AiFallbackReason.cancelled,
        );
      } else {
        final r = await widget.aiRunner.generateReflection(
          fresh,
          baseline: baseline,
        );
        outcome = (text: r.text, mode: r.mode, reason: r.fallbackReason);
      }
      if (!mounted || gen != _gen) return;
      await widget.repository.updateReport(id, outcome.text, outcome.mode);
      if (!mounted || gen != _gen) return;
      final updated = await widget.repository.findById(id);
      if (!mounted || gen != _gen) return;
      setState(() {
        _record = updated;
        _baseline = baseline;
        _fallbackReason = outcome.reason;
        _generating = false;
        _stage = _Stage.result;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _generating = false;
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    final id = widget.recordId;
    try {
      final r = id == null ? null : await widget.repository.findById(id);
      HistoryBaseline? baseline;
      if (r != null && id != null) {
        try {
          baseline = (await _freshAndBaseline(id, r.measuredAt)).$2;
        } catch (_) {
          baseline = null; // 比較は表示しない（捏造しない）。
        }
      }
      if (!mounted) return;
      setState(() {
        _record = r;
        _baseline = baseline;
        _condition = r?.selfCondition;
        _temperature = r?.bodyTemperatureC;
        _stage = r?.reportText == null ? _Stage.input : _Stage.result;
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

  /// 体調・体温を同じ記録IDへ保存する。保存済みのレポートは入力が変わるため消える。
  Future<bool> _saveInputs() async {
    final id = widget.recordId;
    if (id == null || _saving || !_temperatureValid) return false;
    final c = _condition;
    final t = _temperature;
    setState(() {
      _saving = true;
      _inputMsg = null;
    });
    var success = false;
    try {
      final current = await widget.repository.findById(id);
      if (current == null) throw StateError('record missing');
      final updated = HealthCheckResult(
        id: current.id,
        measuredAt: current.measuredAt,
        elapsed: current.elapsed,
        faceDetected: current.faceDetected,
        quality: current.quality,
        scanMode: current.scanMode,
        estimatedHeartRateBpm: current.estimatedHeartRateBpm,
        heartRateSource: current.heartRateSource,
        faceColorFeature: current.faceColorFeature,
        selfCondition: c,
        bodyTemperatureC: t,
        temperatureSource: t == null
            ? TemperatureSource.none
            : t == current.bodyTemperatureC
            ? current.temperatureSource
            : TemperatureSource.manual,
      );
      if (!await widget.repository.updateInputsAndReport(updated)) {
        throw StateError('record missing');
      }
      if (!mounted) return false;
      _record = updated;
      success = true;
    } catch (_) {
      // 下書き（不正な文字列を含む）は残し、再試行できるようにする。
    }
    if (mounted) {
      setState(() {
        _saving = false;
        if (!success) _inputMsg = '入力を保存できませんでした（保存されていません）。もう一度お試しください。';
      });
    }
    return success;
  }

  Future<void> _submit() async {
    if (_saving || _generating || !_temperatureValid) return;
    if (!await _saveInputs() || !mounted) return;
    _wantTemplate = false;
    await _generateReport();
  }

  void _retry() {
    _wantTemplate = false;
    _generateReport();
  }

  void _showTemplate() {
    _wantTemplate = true;
    if (_generating) {
      widget.aiRunner.cancel(); // 生成中ならAIを止め、定型文で続ける。
    } else {
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _pachinko && _stage == _Stage.input && _record != null;
    final page = Scaffold(
      backgroundColor: _pachinko ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: _pachinko ? Colors.transparent : null,
        title: !banner && _stage == _Stage.input && _record != null
            ? const Text(
                '計測できました',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AsakaoStyle.muted,
                ),
              )
            : null,
        centerTitle: true,
      ),
      // 4-1 → 4-2 → 4-3 / 4-2' は同じ場所の fade。
      body: SafeArea(
        child: Column(
          children: [
            if (banner)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PachinkoBanner(),
              ),
            Expanded(
              child: AppTransitions.fadeSwitch(
                child: KeyedSubtree(
                  key: ValueKey((_loading, _loadError, _stage)),
                  child: _body(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return _pachinko ? PachinkoBackground(child: page) : page;
  }

  /// 本文（スクロール）と下部ボタンを分けて固定する。
  Widget _page({
    required List<Widget> children,
    required List<Widget> actions,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final r = _record;
    if (_loadError || r == null) {
      return _page(
        children: [
          const SizedBox(height: 24),
          Text(
            _loadError ? '記録を読み込めませんでした。' : '該当する記録が見つかりません。',
            style: AsakaoStyle.body,
          ),
        ],
        actions: [
          if (_loadError) ...[
            OutlinedButton(onPressed: _load, child: const Text('再読み込み')),
            const SizedBox(height: 8),
          ],
          AsakaoPrimaryButton(label: 'ホームへ', onPressed: widget.onBackToHome),
        ],
      );
    }
    return switch (_stage) {
      _Stage.input => _inputView(),
      _Stage.generating => _generatingView(),
      _Stage.failed => _failedView(),
      _Stage.result => _resultView(r),
    };
  }

  /// キットは接続中か未接続かだけを出す。保存した環境の値は履歴の詳細で見られる。
  /// ただし環境情報の保存に失敗したときは、隠さずに知らせて再試行できるようにする。
  List<Widget> _kitInformation() => [
    if (widget.ledService case final service?) ...[
      const SizedBox(height: 16),
      Center(child: LedKitBadge(service: service)),
    ],
    if ((widget.environmentSaves, widget.recordId) case (
      final saves?,
      final id?,
    ))
      ListenableBuilder(
        listenable: saves,
        builder: (context, _) =>
            saves.stateFor(id) != EnvironmentSaveState.failed
            ? const SizedBox.shrink()
            : Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'チェックは保存済みです。環境情報を保存できませんでした',
                    textAlign: TextAlign.center,
                    style: AsakaoStyle.caption,
                  ),
                  TextButton(
                    onPressed: () => saves.retry(id),
                    child: const Text('環境情報の保存を再試行'),
                  ),
                ],
              ),
      ),
  ];

  // ---- 4-1 自己申告 ----

  Widget _inputView() {
    return _page(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AsakaoStyle.linkPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 20, color: AsakaoStyle.link),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('15秒の計測が終わりました。あと少しです。', style: AsakaoStyle.body),
            ),
          ],
        ),
        ..._kitInformation(),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: const Text('いまの体調は？', style: AsakaoStyle.title),
        ),
        const SizedBox(height: 4),
        const Text('直感で選んでください', style: AsakaoStyle.caption),
        const SizedBox(height: 12),
        SelfConditionInput(
          value: _condition,
          onChanged: (v) => setState(() {
            _condition = v;
            _inputMsg = null;
          }),
        ),
        const SizedBox(height: 16),
        ManualTemperatureInput(
          enabled: !_saving,
          value: _temperature,
          onChanged: (v) => setState(() {
            _temperature = v;
            _inputMsg = null;
          }),
          onValidityChanged: (v) => setState(() => _temperatureValid = v),
        ),
        if (_inputMsg != null) ...[
          const SizedBox(height: 12),
          Text(
            _inputMsg!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AsakaoStyle.destructive,
            ),
          ),
        ],
      ],
      actions: [
        AsakaoPrimaryButton(
          label: '結果を見る',
          onPressed: _saving || _generating || !_temperatureValid
              ? null
              : _submit,
        ),
      ],
    );
  }

  // ---- 4-2 レポート生成中・失敗 ----

  Widget _generatingView() {
    return _page(
      children: const [
        SizedBox(height: 48),
        Center(child: AsakaoMascot(mood: AsakaoMascotMood.busy, size: 140)),
        SizedBox(height: 24),
        _Centered('レポートを書いています…', AsakaoStyle.heading),
        SizedBox(height: 12),
        _Centered('記録は保存済みです。', AsakaoStyle.caption),
        _Centered('まとめは数秒で表示されます。', AsakaoStyle.caption),
      ],
      actions: [AsakaoTextLink(label: '定型文で先に見る', onPressed: _showTemplate)],
    );
  }

  Widget _failedView() {
    return _page(
      children: const [
        SizedBox(height: 48),
        Center(child: AsakaoMascot(mood: AsakaoMascotMood.sad, size: 120)),
        SizedBox(height: 24),
        _Centered('まとめを作れませんでした', AsakaoStyle.heading),
        SizedBox(height: 12),
        _Centered('今日の記録は保存済みなので、定型文で結果を確認できます。', AsakaoStyle.body),
      ],
      actions: [
        AsakaoPrimaryButton(label: '定型文で結果を見る', onPressed: _showTemplate),
        const SizedBox(height: 4),
        AsakaoTextLink(label: 'もう一度試す', onPressed: _retry),
      ],
    );
  }

  // ---- 4-3 / 4-5 結果 ----

  Widget _resultView(HealthCheckResult r) {
    final good = r.quality == MeasurementQuality.good;
    final baseline = _baseline;
    final cond = r.selfCondition;
    final median = baseline?.selfConditionMedian;
    final diff = cond != null && median != null ? cond - median : null;
    // 「いつもどおり」は、実際の基準値と同じ体調のときだけ言う。
    final usual = good && diff == 0;
    final headline = !good
        ? '今回は十分な品質で計測できませんでした'
        : usual
        ? 'いつもどおりの朝です'
        : '今日の記録ができました';
    return _page(
      children: [
        Text(
          '${formatJaDate(r.measuredAt)} ${formatClock(r.measuredAt)}',
          style: AsakaoStyle.caption,
        ),
        const SizedBox(height: 4),
        Text('計測モード: ${r.scanMode.label}', style: AsakaoStyle.caption),
        if (r.scanMode == ScanMode.research)
          const Text(
            '研究用の試験機能です。心拍・顔色を健康状態の判定に使用しないでください。',
            style: AsakaoStyle.caption,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            AsakaoMascot(
              mood: !good
                  ? AsakaoMascotMood.sad
                  : usual
                  ? AsakaoMascotMood.happy
                  : AsakaoMascotMood.normal,
              size: 72,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(headline, style: AsakaoStyle.title),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (baseline != null && baseline.isAccumulating) ...[
          _baselineCard(baseline),
          const SizedBox(height: 12),
        ],
        RecordQualityCard(r),
        const AsakaoSectionLabel('今日の記録'),
        RecordValuesCard(r, conditionDiff: diff),
        ..._kitInformation(),
        const AsakaoSectionLabel('今日のレポート'),
        RecordReportCard(
          r,
          missingText: 'レポートは未生成です。',
          fallbackNote:
              r.aiMode == ReportMode.template && _fallbackReason != null
              ? _reasonText(_fallbackReason!)
              : null,
        ),
        const SizedBox(height: 12),
        const Text(
          '医療機器ではありません。値は目安です。診断目的ではありません。体温はカメラでは測定していません。',
          style: AsakaoStyle.caption,
        ),
      ],
      actions: [
        AsakaoPrimaryButton(label: '履歴に戻る', onPressed: widget.onBackToHome),
      ],
    );
  }

  Widget _baselineCard(HistoryBaseline b) {
    // 体調つきの有効記録が3件そろうと比較を表示する（直近7日・今日を除く）。
    final n = b.selfConditionCount.clamp(0, 3);
    return AsakaoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '基準値を蓄積中',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AsakaoStyle.ink,
                  ),
                ),
              ),
              Text(
                '$n / 3',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AsakaoStyle.link,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < n ? AsakaoStyle.link : AsakaoStyle.disabled,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'あと${3 - n}件、体調つきで記録すると普段との比較を表示します。',
            style: AsakaoStyle.caption,
          ),
        ],
      ),
    );
  }

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
    AiFallbackReason.cancelled => '先に定型文で表示しています',
    AiFallbackReason.unsupported ||
    AiFallbackReason.restricted ||
    AiFallbackReason.bridgeUnavailable ||
    AiFallbackReason.unavailable ||
    AiFallbackReason.disposed => 'この端末では端末内AIを使えないため、定型文で表示しています',
  };
}

class _Centered extends StatelessWidget {
  const _Centered(this.text, this.style);
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style, textAlign: TextAlign.center);
}
