import 'dart:async';

import 'package:flutter/material.dart';

import '../features/scan/camera_scan_service.dart';
import '../features/scan/scan_widget.dart';
import '../models/health_check_result.dart';
import '../models/scan_contract.dart';
import '../services/db/health_record_store.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.store, this.serviceFactory});
  final HealthRecordStore store;
  final HealthScanService Function()? serviceFactory;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final HealthScanService _service =
      widget.serviceFactory?.call() ?? CameraScanService();
  bool _running = false;
  bool _saving = false;
  HealthCheckResult? _unsaved;
  String? _error;

  Future<void> _start() async {
    if (_running || _saving || _unsaved != null) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final outcome = await _service.startHealthScan();
      if (!mounted) return;
      setState(() => _running = false);
      switch (outcome) {
        case ScanSuccess(:final result):
          _unsaved = result;
          await _save();
        case ScanFailure(:final reason):
          setState(() => _error = _failureText(reason));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = 'カメラを開始できませんでした。撮影画面を開き直してください。';
        });
      }
    }
  }

  Future<void> _save() async {
    final result = _unsaved;
    if (_saving || result == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.insert(result);
      _unsaved = null;
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(store: widget.store, result: result),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '測定結果を保存できませんでした。保存を再試行してください。';
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && _unsaved == null,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) unawaited(_service.cancelScan());
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('15秒チェック')),
      body: SafeArea(
        child: StreamBuilder<ScanProgress>(
          stream: _service.progress,
          initialData: _service.currentProgress,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? _service.currentProgress;
            final camera = _service;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('顔を中央に合わせ、明るい場所で動かずに撮影してください。'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: camera is CameraScanService
                      ? ClipRect(
                          child: ScanWidget(
                            service: camera,
                            preview: camera.preview,
                            placeholder: const Center(
                              child: Text('開始するとカメラを準備します'),
                            ),
                            overlay: Center(
                              child: Container(
                                width: 180,
                                height: 240,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const Center(child: Text('計測プレビュー')),
                ),
                const SizedBox(height: 16),
                Text(
                  _saving
                      ? '測定結果を保存中…'
                      : switch (progress.phase) {
                          ScanPhase.preparing => _guidanceText(
                            progress.guidance,
                          ),
                          ScanPhase.measuring =>
                            '残り ${progress.remaining.inSeconds + (progress.remaining.inMilliseconds % 1000 > 0 ? 1 : 0)} 秒',
                          ScanPhase.completed => '15秒の計測が完了しました',
                          ScanPhase.failed => '測定できませんでした。再試行してください。',
                          ScanPhase.idle => '顔位置の確認後に15秒の計測が始まります',
                        },
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!),
                ],
                const SizedBox(height: 16),
                if (_unsaved != null)
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('保存を再試行'),
                  )
                else
                  FilledButton(
                    onPressed: _running || _saving ? null : _start,
                    child: const Text('計測開始 / 再試行'),
                  ),
                if (_running)
                  TextButton(
                    onPressed: () => _service.cancelScan(),
                    child: const Text('計測を中断'),
                  ),
                const Text('撮影画像・動画は保存しません。心拍数と体温はカメラで測定しません。'),
              ],
            );
          },
        ),
      ),
    ),
  );
}

String _guidanceText(ScanGuidance? guidance) => switch (guidance) {
  ScanGuidance.lowLight => '顔が明るく映る場所へ移動してください',
  ScanGuidance.multipleFaces => '一人で撮影してください',
  ScanGuidance.offAngle => '顔を正面に向けてください',
  ScanGuidance.moving => '顔を動かさずにお待ちください',
  ScanGuidance.faceTooSmall => 'カメラに少し近づいてください',
  ScanGuidance.faceTooLarge => 'カメラから少し離れてください',
  _ => '顔を画面の中央に合わせてください',
};

String _failureText(ScanFailureReason reason) => switch (reason) {
  ScanFailureReason.permissionDenied =>
    'カメラの許可が必要です。iPhoneの設定 → アプリ → 15秒健康チェックでカメラを許可してください。',
  ScanFailureReason.faceNotFound => '顔が見つかりません。中央に合わせて再測定してください。',
  ScanFailureReason.poorQuality => '明るい場所で動かずに再測定してください。',
  ScanFailureReason.interrupted => '測定が中断されました。記録は保存していません。',
  ScanFailureReason.cameraUnavailable => 'カメラを利用できません。撮影画面を開き直してください。',
  ScanFailureReason.processingFailed => '画像処理に失敗しました。撮影画面を開き直してください。',
};
