import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../models/health_check_result.dart';
import 'on_device_ai_client.dart';
import 'template_record_summary.dart';

/// Internal execution result, not the unagreed B/C HealthReport storage API.
class AiTextOutcome {
  const AiTextOutcome._(this.text, this.mode, this.fallbackReason);
  final String text;
  final ReportMode mode;
  final AiFallbackReason? fallbackReason;
}

/// One local request at a time, with bounded UI wait and deterministic fallback.
/// It never writes to a DB, alters a scan, calculates history or downloads a model.
class OnDeviceAiRunner {
  OnDeviceAiRunner({required this._client, required Duration timeout})
    : _timeout = timeout {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
  }

  final OnDeviceAiClient _client;
  final Duration _timeout;
  final _summary = const TemplateRecordSummary();
  bool _busy = false;
  bool _disposed = false;
  _Pending? _active;

  /// Can remain true after timeout until the native future actually settles.
  bool get isNativeBusy => _busy;

  Future<AiTextOutcome> generateReflection(HealthCheckResult scan) {
    if (_disposed) {
      return Future.value(_fallback(scan, AiFallbackReason.disposed));
    }
    if (_busy) return Future.value(_fallback(scan, AiFallbackReason.busy));
    if (scan.quality != MeasurementQuality.good) {
      return Future.value(_fallback(scan, AiFallbackReason.invalidScan));
    }
    final pending = _Pending(scan, _requestId());
    _active = pending;
    _busy = true;
    pending.timer = Timer(_timeout, () {
      _finishFallback(pending, AiFallbackReason.timedOut);
      _requestCancel(pending);
    });
    unawaited(_perform(pending));
    return pending.result.future;
  }

  Future<void> _perform(_Pending pending) async {
    try {
      final availability = await _client.checkAvailability();
      if (_active != pending) return;
      if (availability != AiAvailability.available) {
        _finishFallback(pending, switch (availability) {
          AiAvailability.unsupported => AiFallbackReason.unsupported,
          AiAvailability.disabled => AiFallbackReason.disabled,
          AiAvailability.modelNotReady => AiFallbackReason.modelNotReady,
          AiAvailability.initializing => AiFallbackReason.initializing,
          AiAvailability.restricted => AiFallbackReason.restricted,
          AiAvailability.bridgeUnavailable =>
            AiFallbackReason.bridgeUnavailable,
          AiAvailability.unavailable => AiFallbackReason.unavailable,
          AiAvailability.available => throw StateError(
            'Unexpected availability',
          ),
        });
        return;
      }
      final allowed = [
        _Reflection.reviewRecord,
        if (pending.scan.selfCondition != null) _Reflection.reviewSelfCondition,
        if (pending.scan.bodyTemperatureC != null)
          _Reflection.reviewTemperature,
      ];
      pending.generating = true;
      final output = await _client.generateReflection(
        requestId: pending.requestId,
        instructions:
            '記録の振り返りに添える短文を選択します。'
            'allowedReflections内のキーを一つだけ返してください。'
            '説明文、数値の推測、健康状態の判定、病名は返さないでください。',
        prompt: jsonEncode({
          'quality': pending.scan.quality.name,
          'selfCondition': pending.scan.selfCondition,
          'hasTemperature': pending.scan.bodyTemperatureC != null,
          'allowedReflections': allowed.map((value) => value.name).toList(),
        }),
      );
      if (_active != pending) return;
      if (output.length > 64) {
        _finishFallback(pending, AiFallbackReason.invalidResponse);
        return;
      }
      final matches = allowed.where((choice) => choice.name == output.trim());
      if (matches.length != 1) {
        _finishFallback(pending, AiFallbackReason.invalidResponse);
        return;
      }
      final text =
          '生成モード：端末内AI（短文選択）\n'
          '${_summary.formatRecord(pending.scan)}\n補足：${matches.single.text}';
      _complete(pending, AiTextOutcome._(text, ReportMode.onDevice, null));
    } on AiClientFailure catch (error) {
      _finishFallback(pending, error.reason);
    } on Object {
      _finishFallback(
        pending,
        pending.generating
            ? AiFallbackReason.generationFailed
            : AiFallbackReason.availabilityCheckFailed,
      );
    } finally {
      _busy = false;
    }
  }

  AiTextOutcome _fallback(HealthCheckResult scan, AiFallbackReason reason) =>
      AiTextOutcome._(_summary.format(scan), ReportMode.template, reason);

  void _finishFallback(_Pending pending, AiFallbackReason reason) {
    if (_active == pending) _complete(pending, _fallback(pending.scan, reason));
  }

  void _complete(_Pending pending, AiTextOutcome outcome) {
    if (_active != pending) return;
    pending.timer?.cancel();
    _active = null; // A late native completion cannot replace this result.
    pending.result.complete(outcome);
  }

  /// Completes the caller immediately; native cancellation is best effort.
  void cancel() {
    final pending = _active;
    if (pending == null) return;
    _finishFallback(pending, AiFallbackReason.cancelled);
    _requestCancel(pending);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final pending = _active;
    if (pending == null) return;
    _finishFallback(pending, AiFallbackReason.disposed);
    _requestCancel(pending);
  }

  void _requestCancel(_Pending pending) {
    if (!pending.generating || pending.cancelRequested) return;
    pending.cancelRequested = true;
    // Do not free _busy on a cancellation acknowledgement. The original request
    // must settle too; otherwise a timed-out task could overlap a new generation.
    unawaited(
      Future<void>.sync(() => _client.cancelGeneration(pending.requestId))
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
    );
  }

  static String _requestId() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}

class _Pending {
  _Pending(this.scan, this.requestId);
  final HealthCheckResult scan;
  final String requestId;
  final result = Completer<AiTextOutcome>();
  Timer? timer;
  bool generating = false;
  bool cancelRequested = false;
}

// The raw model response is never shown. Only applicable predefined sentences
// can be selected, so it cannot add health numbers, diagnoses or invented facts.
enum _Reflection {
  reviewRecord('記録した内容を振り返ってください。'),
  reviewSelfCondition('自己申告の体調も、記録を振り返る手がかりになります。'),
  reviewTemperature('体温は表示された出典と合わせて振り返ってください。');

  const _Reflection(this.text);
  final String text;
}
