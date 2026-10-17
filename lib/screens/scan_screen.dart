import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/scan/scan_widget.dart';
import '../models/health_check_result.dart';
import '../models/scan_contract.dart';
import '../navigation/app_routes.dart';
import '../services/db/health_record_repository.dart';

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
  });

  final HealthRecordRepository repository;
  final ScanSession Function() createSession;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Stage { idle, running, saving, saveFailed, failed }

class _ScanScreenState extends State<ScanScreen> {
  late final ScanSession _session = widget.createSession();
  _Stage _stage = _Stage.idle;
  ScanFailureReason? _failure;
  HealthCheckResult? _unsaved;
  bool _leaving = false;
  bool _canPop = false;
  Future<void>? _releasing;
  Future<void>? _cancelling;
  int _attempt = 0; // 新しい試行・離脱・破棄後の古い結果を捨てるための世代

  @override
  void dispose() {
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
    if (_leaving || (_stage != _Stage.idle && _stage != _Stage.failed)) return;
    final retry = _stage == _Stage.failed;
    final attempt = ++_attempt;
    setState(() {
      _stage = _Stage.running;
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
      setState(() {
        _stage = _Stage.failed;
        _failure = ScanFailureReason.processingFailed;
      });
      return;
    }
    if (!_isCurrent(attempt)) return;
    switch (outcome) {
      case ScanSuccess(:final result):
        await _save(result, attempt);
      case ScanFailure(:final reason):
        setState(() {
          _stage = _Stage.failed;
          _failure = reason;
        });
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
      setState(() => _stage = _Stage.saveFailed);
      return;
    }
    if (!_isCurrent(attempt)) return;
    try {
      await _release();
    } catch (_) {
      // The record is saved. Cleanup failure must not trigger a duplicate insert.
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
    final busy =
        _leaving || _stage == _Stage.running || _stage == _Stage.saving;
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('15秒チェック'),
          leading: BackButton(onPressed: _leaving ? null : _leave),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ScanWidget(
                      service: _session.service,
                      preview: _session.preview,
                      placeholder: const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Text('カメラを準備しています')),
                      ),
                      overlay: const Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          heightFactor: 0.6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white70, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<ScanProgress>(
                  stream: _session.service.progress,
                  initialData: _session.service.currentProgress,
                  builder: (context, snap) => _progress(
                    context,
                    snap.data ?? _session.service.currentProgress,
                  ),
                ),
                const SizedBox(height: 16),
                ..._status(),
                const SizedBox(height: 16),
                if (_stage == _Stage.saveFailed)
                  FilledButton(
                    onPressed: _leaving
                        ? null
                        : () => _save(_unsaved!, _attempt),
                    child: const Text('保存を再試行'),
                  )
                else
                  FilledButton(
                    onPressed: busy ? null : _start,
                    child: Text(_stage == _Stage.failed ? '再試行' : '開始'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'このアプリは診断目的ではありません。画像や動画は保存されません。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progress(BuildContext context, ScanProgress p) {
    final style = Theme.of(context).textTheme.titleMedium;
    final text = switch (p.phase) {
      ScanPhase.preparing =>
        p.guidance == null ? '顔の位置を確認しています' : _guidance(p.guidance!),
      ScanPhase.measuring =>
        '計測中　残り ${(p.remaining.inMilliseconds / 1000).ceil()} 秒',
      _ => '顔を枠に合わせて、開始を押してください',
    };
    return Text(text, style: style, textAlign: TextAlign.center);
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

  List<Widget> _status() {
    final message = switch (_stage) {
      _Stage.saving => '記録を保存しています…',
      _Stage.saveFailed => '記録を保存できませんでした。結果は保存されていません。もう一度保存を試してください。',
      _Stage.failed => _failureMessage(_failure!),
      _ => null,
    };
    return [if (message != null) Text(message, textAlign: TextAlign.center)];
  }

  static String _failureMessage(ScanFailureReason r) => switch (r) {
    ScanFailureReason.permissionDenied =>
      'カメラの許可が必要です。顔を映して計測するためにだけ使います。設定アプリから許可してください。',
    ScanFailureReason.faceNotFound || ScanFailureReason.poorQuality =>
      'うまく計測できませんでした。顔が枠の中央に入るよう位置を調整し、明るい場所でもう一度お試しください。記録は保存されていません。',
    ScanFailureReason.interrupted => '計測が中断されました。記録は保存されていません。もう一度お試しください。',
    ScanFailureReason.cameraUnavailable || ScanFailureReason.processingFailed =>
      '計測の途中で問題が起きました（技術的な失敗です）。記録は保存されていません。もう一度お試しください。',
  };
}
