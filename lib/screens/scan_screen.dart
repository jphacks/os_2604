import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../features/scan/scan_widget.dart';
import '../models/health_check_result.dart';
import '../models/scan_contract.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_transitions.dart';
import '../services/db/health_record_repository.dart';
import '../services/sound/sound_effects.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';
import '../ui/pachinko_effects.dart';

/// 画面が1つ所有する計測サービスとそのプレビュー。
typedef ScanSession = ({
  HealthScanService service,
  ValueListenable<CameraController?> preview,
});

/// 撮影画面。時計はサービス（C）が持つ。成功したら先にDBへ保存してから結果へ進む。
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.repository,
    required this.createSession,
    this.researchMode = false,
  });

  final HealthRecordRepository repository;
  final ScanSession Function() createSession;
  final bool researchMode;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

/// [failed] は中断画面（3-3）、[interrupted] はカメラの画面のままダイアログで知らせる中断。
enum _Stage { idle, running, saving, saveFailed, failed, interrupted }

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  // 計測の進み（円と残り秒数）は、届いた経過時間のあいだを毎フレーム補って滑らかに動かす。
  // 次の通知が来ないとき（条件が崩れて止まったとき）は先へ進みすぎないよう上限を設ける。
  static const _maxLead = Duration(milliseconds: 400);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _tickNow = Duration.zero;
  Duration _eventTick = Duration.zero;
  Duration _eventElapsed = Duration.zero;
  final _smoothElapsed = ValueNotifier(Duration.zero);

  void _onTick(Duration now) {
    _tickNow = now;
    final lead = now - _eventTick;
    final next = _eventElapsed + (lead > _maxLead ? _maxLead : lead);
    final capped = next > HealthCheckResult.targetDuration
        ? HealthCheckResult.targetDuration
        : next;
    // 戻らない（新しい通知が少し前の値でも、表示は前へだけ進む）。
    if (capped > _smoothElapsed.value) _smoothElapsed.value = capped;
    // 計測が終わった・止まったら、次の通知までフレームを回さない。
    if (_stage != _Stage.running ||
        lead >= _maxLead ||
        capped >= HealthCheckResult.targetDuration) {
      _ticker.stop();
    }
  }

  /// パチンコ風の計測完了：画面を暗転し、暗転の音（約0.94秒）が終わったら体調の入力へ進む。
  static const _blackoutDuration = Duration(milliseconds: 950);
  late final _blackoutAnimation = AnimationController(
    vsync: this,
    duration: _blackoutDuration,
  );
  bool _blackout = false;
  Future<void>? _blackoutDone;

  /// 最後に鳴らした音（0 = 最初のド）。計測側から届いた秒数で進める。
  int _lastNote = -1;

  void _onMeasuringProgress(ScanProgress p) {
    if (p.phase != ScanPhase.measuring) {
      if (_ticker.isActive) _ticker.stop();
      _smoothElapsed.value = Duration.zero;
      _eventElapsed = Duration.zero;
      _lastNote = -1;
      return;
    }
    // 残り 15 → 1 秒の数字ごとに、ド〜2オクターブ上のドを1音ずつ鳴らす。
    // 滑らかに補った表示ではなく、実際に届いた経過秒で鳴らす（止まれば音も止まる）。
    final note = p.elapsed.inSeconds.clamp(0, 14);
    if (note > _lastNote && _stage == _Stage.running) {
      _lastNote = note;
      SoundEffects.playNote(note);
    }
    _eventElapsed = p.elapsed;
    _eventTick = _tickNow;
    if (p.elapsed > _smoothElapsed.value) _smoothElapsed.value = p.elapsed;
    if (!_ticker.isActive) {
      _tickNow = Duration.zero;
      _eventTick = Duration.zero;
      _ticker.start();
    }
  }

  late final ScanSession _session = widget.createSession();
  _Stage _stage = _Stage.idle;
  ScanFailureReason? _failure;
  bool _failureShown = false; // 3-3 の fade が終わったら計測画面を隠す
  HealthCheckResult? _unsaved;
  bool _leaving = false;
  bool _canPop = false;
  Future<void>? _releasing;
  Future<void>? _cancelling;
  int _attempt = 0; // 新しい試行・離脱・破棄後の古い結果を捨てるための世代

  // 準備中に一度でも指摘（guidance）が出たか。guidance==null は「最初のフレーム前」と
  // 「条件がそろった」を区別できないため、指摘が消えた場合だけ「条件がそろった」と扱う。
  bool _seenGuidance = false;
  StreamSubscription<ScanProgress>? _progressSub;

  /// 「撮影準備」の音はこの試行で1回だけ鳴らす。
  bool _readySounded = false;

  @override
  void initState() {
    super.initState();
    // 3-1'。画面を開いたらすぐにカメラを起動し、条件がそろえば自動で計測を始める。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
    _progressSub = _session.service.progress.listen((p) {
      _onMeasuringProgress(p);
      final seen =
          p.phase == ScanPhase.preparing &&
          (p.guidance != null || _seenGuidance);
      if (seen != _seenGuidance && mounted) {
        setState(() => _seenGuidance = seen);
      }
      // 3つの条件がそろった（または計測に入った）ら、撮影準備の音を1回鳴らす。
      final ready =
          p.phase == ScanPhase.measuring ||
          (p.phase == ScanPhase.preparing && _conditionsFor(p, seen).ready);
      if (ready && !_readySounded && _stage == _Stage.running && mounted) {
        _readySounded = true;
        SoundEffects.play(SoundEffect.ready);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blackoutAnimation.dispose();
    _smoothElapsed.dispose();
    unawaited(_progressSub?.cancel());
    _attempt++;
    unawaited(_release().catchError((Object _) {}));
    super.dispose();
  }

  bool _isCurrent(int attempt) =>
      mounted &&
      !_leaving &&
      attempt == _attempt &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _cancel() => _cancelling ??= () async {
    try {
      await _session.service.cancelScan();
    } finally {
      _cancelling = null;
    }
  }();

  // Disposal also runs for routes removed by the parent Navigator. Share the
  // operation with leave/navigation so overlapping callbacks release only once.
  Future<void> _release() => _releasing ??= () async {
    try {
      await _cancel();
    } finally {
      await _session.service.dispose();
    }
  }();

  Future<void> _start() async {
    if (_leaving ||
        (_stage != _Stage.idle &&
            _stage != _Stage.failed &&
            _stage != _Stage.interrupted)) {
      return;
    }
    final retry = _stage == _Stage.failed || _stage == _Stage.interrupted;
    final attempt = ++_attempt;
    setState(() {
      _stage = _Stage.running;
      _readySounded = false;
      _failureShown = false;
      _failure = null;
      _unsaved = null;
    });
    final ScanOutcome outcome;
    try {
      if (retry) await _cancel();
      if (!_isCurrent(attempt)) return;
      outcome = await _session.service.startHealthScan();
    } catch (_) {
      if (!_isCurrent(attempt)) return;
      _fail(ScanFailureReason.processingFailed);
      return;
    }
    if (!_isCurrent(attempt)) return;
    switch (outcome) {
      case ScanSuccess(:final result):
        if (SoundEffects.pachinkoFinish) {
          // パチンコ風：保存と並行して画面を暗転させ、暗転の音が終わるまで待ってから進む。
          setState(() => _blackout = true);
          SoundEffects.play(SoundEffect.pachinkoBlackout);
          _blackoutDone = _blackoutAnimation
              .forward(from: 0)
              .orCancel
              .catchError((Object _) {});
        } else {
          SoundEffects.play(SoundEffect.measureDone);
        }
        await _save(result, attempt);
      case ScanFailure(:final reason):
        _fail(reason);
    }
  }

  /// 設定アプリでの手順が要る中断は、これまでどおり中断画面（3-3）で説明する。
  static bool _needsScreen(ScanFailureReason r) =>
      r == ScanFailureReason.permissionDenied ||
      r == ScanFailureReason.cameraUnavailable;

  bool _dialogOpen = false;

  /// 計測が無効になった。記録は保存しない。
  /// 顔が外れた・暗い・離脱などは、カメラの画面のままダイアログで知らせ、
  /// 「もう一度測る」で状態をリセットして条件のチェックから再開する（自動では撮り直さない）。
  void _fail(ScanFailureReason reason) {
    SoundEffects.play(SoundEffect.pause);
    if (_needsScreen(reason)) {
      setState(() {
        _stage = _Stage.failed;
        _failure = reason;
      });
      return;
    }
    setState(() {
      _stage = _Stage.interrupted;
      _failure = reason;
      _seenGuidance = false;
    });
    unawaited(_showInterrupted(reason));
  }

  Future<void> _showInterrupted(ScanFailureReason reason) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InterruptedDialog(copy: _failureCopy(reason)),
    );
    _dialogOpen = false;
    if (!mounted || _leaving) return;
    if (again == true) {
      unawaited(_start());
    } else {
      unawaited(_leave());
    }
  }

  Future<void> _save(HealthCheckResult result, int attempt) async {
    if (!_isCurrent(attempt) || _stage == _Stage.saving) return;
    setState(() {
      _stage = _Stage.saving;
      _unsaved = result;
    });
    try {
      await widget.repository.insert(result);
    } catch (_) {
      if (!_isCurrent(attempt)) return;
      // 保存できなかったことを隠さないよう、暗転はやめて再試行を見せる。
      setState(() {
        _stage = _Stage.saveFailed;
        _blackout = false;
        _blackoutAnimation.value = 0;
      });
      return;
    }
    if (!_isCurrent(attempt)) return;
    try {
      await _release();
    } catch (_) {
      // The record is saved. Cleanup failure must not trigger a duplicate insert.
    }
    final blackout = _blackoutDone;
    if (blackout != null) {
      await blackout;
      if (!mounted || !_isCurrent(attempt)) return;
      SoundEffects.play(SoundEffect.pachinkoResult);
    }
    if (!mounted || !_isCurrent(attempt)) return;
    _leaving = true;
    _attempt++;
    unawaited(
      Navigator.of(context)
          .pushReplacementNamed(AppRoutes.result, arguments: result.id),
    );
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _attempt++;
    setState(() {});
    try {
      await _release();
    } catch (_) {
      // Best-effort cleanup must not trap the user on this screen.
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _canPop = true);
    // PopScope must rebuild with canPop=true before requesting the actual pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final failed = _stage == _Stage.failed;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leaving = true;
          _attempt++;
        } else {
          unawaited(_leave());
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: failed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: failed
              ? AsakaoStyle.background
              : AsakaoStyle.scanBackground,
          // 失敗画面（3-3）は fade で重ねる。ScanWidget を外すと計測サービスの
          // cancelScan が走るため、暗い計測画面は fade の後に Offstage で残す。
          body: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(offstage: failed && _failureShown, child: _scanView()),
              if (failed)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppTransitions.fadeDuration,
                    onEnd: () => setState(() => _failureShown = true),
                    builder: (_, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: ColoredBox(
                      color: AsakaoStyle.background,
                      child: _failedView(),
                    ),
                  ),
                ),
              // パチンコ風の計測完了：上下から黒が閉じ、閃光のあと暗転。暗い間は操作を受け付けない。
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_blackout,
                  child: PachinkoBlackout(progress: _blackoutAnimation),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 計測（暗い）画面。Column の子の位置は固定する（ScanWidget の再生成防止）。 ----

  Widget _scanView() {
    return SafeArea(
      child: StreamBuilder<ScanProgress>(
        stream: _session.service.progress,
        initialData: _session.service.currentProgress,
        builder: (context, snap) {
          final p = snap.data ?? _session.service.currentProgress;
          final measuring =
              p.phase == ScanPhase.measuring && _stage == _Stage.running;
          final conditions = _conditionsFor(p, _seenGuidance);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(measuring),
                      Text(
                        widget.researchMode ? '研究モード（試験機能）' : '通常モード',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AsakaoStyle.scanMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _heading(measuring),
                      const SizedBox(height: 16),
                      _guideOval(p, conditions, measuring),
                      const SizedBox(height: 16),
                      measuring ? _remaining(p) : _conditionCards(conditions),
                      measuring
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _conditionChips(conditions),
                            )
                          : const SizedBox.shrink(),
                      measuring
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _statusText(p),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AsakaoStyle.scanMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_stage == _Stage.saveFailed) ...[
                      FilledButton(
                        style: _darkFilled,
                        onPressed: _leaving
                            ? null
                            : () => _save(_unsaved!, _attempt),
                        child: const Text('保存を再試行'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AsakaoStyle.scanText,
                        backgroundColor: AsakaoStyle.scanSurface,
                        side: BorderSide.none,
                        minimumSize: const Size(44, 52),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _leaving ? null : _leave,
                      child: const Text('中止する'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'このアプリは診断目的ではありません。画像や動画は保存されません。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AsakaoStyle.scanMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static final _darkFilled = FilledButton.styleFrom(
    backgroundColor: AsakaoStyle.coral,
    foregroundColor: AsakaoStyle.ink,
    disabledBackgroundColor: AsakaoStyle.scanSurface,
    disabledForegroundColor: AsakaoStyle.scanMuted,
  );

  Widget _header(bool measuring) => measuring
      ? const Align(alignment: Alignment.centerLeft, child: _MeasuringPill())
      : const Text(
          '顔の位置合わせ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AsakaoStyle.scanText,
          ),
          textAlign: TextAlign.center,
        );

  Widget _heading(bool measuring) => measuring
      ? const Text(
          'そのまま動かずに',
          style: TextStyle(
            fontFamily: AsakaoStyle.displayFont,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AsakaoStyle.scanText,
          ),
          textAlign: TextAlign.center,
        )
      : const Column(
          children: [
            Text(
              '枠の中に顔を合わせてください',
              style: TextStyle(
                fontFamily: AsakaoStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AsakaoStyle.scanText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'スマホを顔の正面に持って、顔全体を枠に入れます',
              style: TextStyle(fontSize: 13, color: AsakaoStyle.scanMuted),
              textAlign: TextAlign.center,
            ),
          ],
        );

  Widget _guideOval(ScanProgress p, _Conditions c, bool measuring) {
    final mode = measuring
        ? _GuideMode.measuring
        : c.ready
        ? _GuideMode.ready
        : _GuideMode.notReady;
    return Center(
      // Sibling types change when preparation becomes measurement. Keep this
      // subtree keyed so Flutter retains ScanWidget instead of cancelling it
      // through deactivate/dispose during the countdown transition.
      key: const ValueKey('scan-camera-guide'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: ClipOval(
                  // カメラ本来の縦横比のまま、楕円いっぱいに切り抜いて映す（引き伸ばさない）。
                  child: _CameraCover(
                    preview: _session.preview,
                    child: ScanWidget(
                      service: _session.service,
                      preview: _session.preview,
                      placeholder: ColoredBox(
                        color: AsakaoStyle.scanEllipse,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              p.phase == ScanPhase.idle
                                  ? 'カメラを起動しています'
                                  : 'カメラを準備しています',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AsakaoStyle.scanMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: ValueListenableBuilder(
                  valueListenable: _smoothElapsed,
                  builder: (_, elapsed, _) => CustomPaint(
                    painter: _GuidePainter(
                      mode: mode,
                      progress: measuring
                          ? (elapsed.inMicroseconds /
                                    HealthCheckResult
                                        .targetDuration
                                        .inMicroseconds)
                                .clamp(0.0, 1.0)
                          : 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _remaining(ScanProgress p) => ValueListenableBuilder(
    valueListenable: _smoothElapsed,
    builder: (_, elapsed, _) {
      final shown = elapsed > p.elapsed ? elapsed : p.elapsed;
      final left = HealthCheckResult.targetDuration - shown;
      return _remainingSeconds(
        left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil(),
      );
    },
  );

  Widget _remainingSeconds(int seconds) {
    return Semantics(
      label: '残り $seconds 秒',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text(
            '残り',
            style: TextStyle(fontSize: 15, color: AsakaoStyle.scanMuted),
          ),
          const SizedBox(width: 12),
          // 数字は前の数字が上へ抜け、次の数字が下から入る。
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final entering = child.key == ValueKey(seconds);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(0, entering ? 0.45 : -0.45),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              '$seconds',
              key: ValueKey(seconds),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AsakaoStyle.scanText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '秒',
            style: TextStyle(fontSize: 15, color: AsakaoStyle.scanMuted),
          ),
        ],
      ),
    );
  }

  Widget _conditionCards(_Conditions c) => Row(
    children: [
      for (final (i, item) in [
        ('顔', c.face),
        ('明るさ', c.light),
        ('角度', c.angle),
      ].indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: _ConditionCard(label: item.$1, condition: item.$2),
        ),
      ],
    ],
  );

  Widget _conditionChips(_Conditions c) => Row(
    children: [
      for (final (i, item) in [
        ('顔', c.face),
        ('明るさ', c.light),
        ('角度', c.angle),
      ].indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: _ConditionChip(label: item.$1, condition: item.$2),
        ),
      ],
    ],
  );

  String _statusText(ScanProgress p) {
    switch (_stage) {
      case _Stage.saving:
        return '記録を保存しています…';
      case _Stage.saveFailed:
        return '記録を保存できませんでした。結果は保存されていません。もう一度保存を試してください。';
      default:
        break;
    }
    return switch (p.phase) {
      ScanPhase.requestingPermission => 'カメラの許可を確認しています',
      ScanPhase.preparing =>
        p.guidance == null ? '顔の位置を確認しています' : _guidance(p.guidance!),
      _ => 'カメラで3つの条件を確認します',
    };
  }

  static String _guidance(ScanGuidance g) => switch (g) {
    ScanGuidance.faceNotFound => '顔が見つかりません。画面の枠に顔を合わせてください',
    ScanGuidance.multipleFaces => '映っているのは1人だけにしてください',
    ScanGuidance.missingData => '顔をもう少しはっきり映してください',
    ScanGuidance.lowLight => '少し暗いようです。明るい場所に移動してください',
    ScanGuidance.offAngle => '正面を向いてください',
    ScanGuidance.offCenter => '顔を画面の中央に寄せてください',
    ScanGuidance.faceTooSmall => '少し近づいてください',
    ScanGuidance.faceTooLarge => '少し離れてください',
    ScanGuidance.moving => '動かずに、そのままでお待ちください',
    ScanGuidance.noFrames => 'カメラの映像を待っています',
  };

  /// C の guidance から3条件を求める。判定されていない条件は「確認中」のままにし、
  /// 緑のチェックは実際に通過した条件にだけ付ける。
  /// 判定順は 顔の数 → データ欠落 → 明るさ → 角度 → 位置・大きさ・動き。
  static _Conditions _conditionsFor(ScanProgress p, bool seenGuidance) {
    const unknown = _Condition(_Check.unknown, '確認中');
    const faceOk = _Condition(_Check.ok, '検出');
    const lightOk = _Condition(_Check.ok, '十分');
    const angleOk = _Condition(_Check.ok, '正面');
    const allOk = _Conditions(faceOk, lightOk, angleOk);
    const allUnknown = _Conditions(unknown, unknown, unknown);
    if (p.phase == ScanPhase.measuring) return allOk; // 条件が崩れれば計測は失敗する
    if (p.phase != ScanPhase.preparing) {
      return const _Conditions(
        _Condition(_Check.unknown, '未確認'),
        _Condition(_Check.unknown, '未確認'),
        _Condition(_Check.unknown, '未確認'),
      );
    }
    final g = p.guidance;
    if (g == null) return seenGuidance ? allOk.asReady() : allUnknown;
    _Condition problem(String text) => _Condition(_Check.problem, text);
    return switch (g) {
      ScanGuidance.faceNotFound => _Conditions(
        problem('未検出'),
        unknown,
        unknown,
      ),
      ScanGuidance.multipleFaces => _Conditions(
        problem('複数'),
        unknown,
        unknown,
      ),
      ScanGuidance.missingData => _Conditions(problem('不鮮明'), unknown, unknown),
      ScanGuidance.lowLight => _Conditions(faceOk, problem('不足'), unknown),
      ScanGuidance.offAngle => _Conditions(faceOk, lightOk, problem('要正面')),
      ScanGuidance.offCenter => _Conditions(problem('中央へ'), lightOk, angleOk),
      ScanGuidance.faceTooSmall => _Conditions(problem('遠い'), lightOk, angleOk),
      ScanGuidance.faceTooLarge => _Conditions(problem('近い'), lightOk, angleOk),
      ScanGuidance.moving => _Conditions(problem('動いた'), lightOk, angleOk),
      ScanGuidance.noFrames => allUnknown,
    };
  }

  // ---- 失敗・中断（明るい）画面 ----

  Widget _failedView() {
    final reason = _failure ?? ScanFailureReason.processingFailed;
    final copy = _failureCopy(reason);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (copy.invalidChip)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AsakaoStyle.neutralBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block,
                                size: 14,
                                color: AsakaoStyle.neutralInk,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'この計測は無効になりました',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AsakaoStyle.neutralInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Center(
                      child: AsakaoMascot(
                        mood: AsakaoMascotMood.sad,
                        size: 200,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          copy.heading,
                          style: AsakaoStyle.title,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AsakaoCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AsakaoStyle.coralPale,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              copy.icon,
                              size: 22,
                              color: AsakaoStyle.coralInk,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AsakaoStyle.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(copy.body, style: AsakaoStyle.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (copy.notSavedNote) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          '途中までのデータは保存されません。',
                          style: AsakaoStyle.caption,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AsakaoPrimaryButton(label: 'もう一度測る', onPressed: _start),
            const SizedBox(height: 4),
            AsakaoTextLink(label: '履歴に戻る', onPressed: _leaving ? null : _leave),
          ],
        ),
      ),
    );
  }

  static _FailureCopy _failureCopy(ScanFailureReason r) => switch (r) {
    ScanFailureReason.permissionDenied => const _FailureCopy(
      heading: 'カメラを使えませんでした',
      title: 'カメラの許可が必要です',
      body: '顔を映して計測するためにだけ使います。設定アプリから許可してください。',
      icon: Icons.no_photography_outlined,
      invalidChip: false,
      notSavedNote: false,
    ),
    ScanFailureReason.faceNotFound ||
    ScanFailureReason.poorQuality => const _FailureCopy(
      heading: '計測を中断しました',
      title: 'うまく計測できませんでした',
      body: '顔が枠の中央に入るよう位置を調整し、明るい場所でもう一度お試しください。',
      icon: Icons.center_focus_strong_outlined,
    ),
    ScanFailureReason.interrupted => const _FailureCopy(
      heading: '計測を中断しました',
      title: '計測が中断されました',
      body: '画面を離れるなどして、計測が途中で止まりました。もう一度お試しください。',
      icon: Icons.pause_circle_outline,
    ),
    ScanFailureReason.cameraUnavailable ||
    ScanFailureReason.processingFailed => const _FailureCopy(
      heading: '計測を中断しました',
      title: '計測の途中で問題が起きました',
      body: '技術的な失敗です。もう一度お試しください。',
      icon: Icons.error_outline,
    ),
  };
}

class _FailureCopy {
  const _FailureCopy({
    required this.heading,
    required this.title,
    required this.body,
    required this.icon,
    this.invalidChip = true,
    this.notSavedNote = true,
  });
  final String heading;
  final String title;
  final String body;
  final IconData icon;
  final bool invalidChip;
  final bool notSavedNote;
}

enum _Check { ok, problem, unknown }

class _Condition {
  const _Condition(this.check, this.text);
  final _Check check;
  final String text;
}

class _Conditions {
  const _Conditions(this.face, this.light, this.angle, {this.ready = false});
  final _Condition face;
  final _Condition light;
  final _Condition angle;

  /// 指摘が一度出たあとで消えた＝3条件が通った状態。
  final bool ready;

  _Conditions asReady() => _Conditions(face, light, angle, ready: true);
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.label, required this.condition});
  final String label;
  final _Condition condition;

  @override
  Widget build(BuildContext context) {
    final problem = condition.check == _Check.problem;
    return Semantics(
      container: true,
      label: '$label：${condition.text}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: problem
              ? AsakaoStyle.coral.withValues(alpha: 0.14)
              : AsakaoStyle.scanSurface,
          borderRadius: BorderRadius.circular(16),
          border: problem ? Border.all(color: AsakaoStyle.coral) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              _CheckBadge(condition.check),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AsakaoStyle.scanMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                condition.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AsakaoStyle.scanText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.label, required this.condition});
  final String label;
  final _Condition condition;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label：${condition.text}',
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AsakaoStyle.scanSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CheckBadge(condition.check, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AsakaoStyle.scanText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 色だけに頼らず、✓ / ! / … の形でも状態を示す。
class _CheckBadge extends StatelessWidget {
  const _CheckBadge(this.check, {this.size = 28});
  final _Check check;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (check) {
      _Check.ok => (AsakaoStyle.scanGreen, Icons.check),
      _Check.problem => (AsakaoStyle.coral, Icons.priority_high),
      _Check.unknown => (AsakaoStyle.scanRingIdle, Icons.more_horiz),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.62, color: AsakaoStyle.scanText),
    );
  }
}

class _MeasuringPill extends StatelessWidget {
  const _MeasuringPill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AsakaoStyle.scanGreen.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AsakaoStyle.scanGreen),
          SizedBox(width: 8),
          Text(
            '計測中',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AsakaoStyle.scanText,
            ),
          ),
        ],
      ),
    ),
  );
}

enum _GuideMode { notReady, ready, measuring }

/// 顔の位置合わせの楕円。未達=コーラルの破線、条件OK=緑の実線、計測中=進捗リング。
class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.mode, required this.progress});
  final _GuideMode mode;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    switch (mode) {
      case _GuideMode.notReady:
        paint.color = AsakaoStyle.coral;
        const dash = 12.0;
        const gap = 9.0;
        for (final metric in (Path()..addOval(rect)).computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += dash + gap) {
            canvas.drawPath(
              metric.extractPath(d, math.min(d + dash, metric.length)),
              paint,
            );
          }
        }
      case _GuideMode.ready:
        paint.color = AsakaoStyle.scanGreen;
        canvas.drawOval(rect, paint);
      case _GuideMode.measuring:
        paint.color = AsakaoStyle.scanRingIdle;
        canvas.drawOval(rect, paint);
        if (progress > 0) {
          paint.color = AsakaoStyle.coral;
          canvas.drawPath(
            Path()..arcTo(rect, -math.pi / 2, 2 * math.pi * progress, true),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.mode != mode || old.progress != progress;
}

/// カメラの映像を本来の縦横比のまま、枠いっぱいに覆うように置く（はみ出しは親で切る）。
/// 子（ScanWidget）の位置は常に同じにして、映像の準備前後で作り直さない。
class _CameraCover extends StatelessWidget {
  const _CameraCover({required this.preview, required this.child});

  final ValueListenable<CameraController?> preview;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => ValueListenableBuilder<CameraController?>(
      valueListenable: preview,
      builder: (_, camera, child) {
        var width = box.maxWidth;
        var height = box.maxHeight;
        final value = camera?.value;
        if (value != null && value.isInitialized && value.aspectRatio > 0) {
          // 縦持ちでは映像の縦横比は 1 / aspectRatio（幅 / 高さ）。
          final ratio = 1 / value.aspectRatio;
          if (width / height > ratio) {
            height = width / ratio;
          } else {
            width = height * ratio;
          }
        }
        return OverflowBox(
          minWidth: width,
          maxWidth: width,
          minHeight: height,
          maxHeight: height,
          child: child,
        );
      },
      child: child,
    ),
  );
}

/// 計測が無効になったときのダイアログ。こまった顔と理由、もう一度／やめる。
class _InterruptedDialog extends StatefulWidget {
  const _InterruptedDialog({required this.copy});

  final _FailureCopy copy;

  @override
  State<_InterruptedDialog> createState() => _InterruptedDialogState();
}

class _InterruptedDialogState extends State<_InterruptedDialog> {
  // 連打で2回閉じると、下の計測画面まで閉じてしまうので1回だけにする。
  bool _closed = false;

  void _close(bool again) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(again);
  }

  _FailureCopy get copy => widget.copy;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AsakaoStyle.background,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AsakaoMascot(mood: AsakaoMascotMood.sad, size: 110),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              copy.title,
              textAlign: TextAlign.center,
              style: AsakaoStyle.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.body,
            textAlign: TextAlign.center,
            style: AsakaoStyle.body.copyWith(color: AsakaoStyle.muted),
          ),
          const SizedBox(height: 8),
          const Text(
            'この計測は無効になりました。記録は保存されていません。',
            textAlign: TextAlign.center,
            style: AsakaoStyle.caption,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AsakaoPrimaryButton(
              label: 'もう一度測る',
              onPressed: () => _close(true),
            ),
          ),
          AsakaoTextLink(label: 'やめる', onPressed: () => _close(false)),
        ],
      ),
    ),
  );
}
