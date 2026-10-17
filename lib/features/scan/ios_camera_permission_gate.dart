import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'scan_permission_gate.dart';

/// Permission dialogs temporarily make iOS inactive. Do not open the camera
/// until permission is granted AND the application returns to the foreground.
class IosCameraPermissionGate
    with WidgetsBindingObserver
    implements ScanPermissionGate {
  IosCameraPermissionGate({
    this._channel = const MethodChannel('jp.jphacks.os_2604/camera_permission'),
  });

  final MethodChannel _channel;
  Completer<bool>? _pending;
  bool _granted = false;

  @override
  Future<bool> request() {
    if (_pending != null) {
      return Future.error(
        StateError('A permission request is already active.'),
      );
    }
    final pending = Completer<bool>();
    _pending = pending;
    _granted = false;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_request(pending));
    return pending.future;
  }

  Future<void> _request(Completer<bool> pending) async {
    try {
      final value = await _channel.invokeMethod<Object?>(
        'requestCameraPermission',
      );
      if (_pending != pending) return;
      if (value is! bool) {
        throw StateError('Invalid camera permission response.');
      }
      if (!value) {
        _complete(false);
        return;
      }
      _granted = true;
      _completeIfResumed();
    } on Object catch (error, stack) {
      if (_pending != pending) return;
      _detach();
      pending.completeError(error, stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _completeIfResumed();
  }

  void _completeIfResumed() {
    if (_granted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _complete(true);
    }
  }

  void _complete(bool granted) {
    final pending = _pending;
    if (pending == null) return;
    _detach();
    pending.complete(granted);
  }

  void _detach() {
    WidgetsBinding.instance.removeObserver(this);
    _pending = null;
    _granted = false;
  }

  @override
  void cancel() => _complete(false);
}
