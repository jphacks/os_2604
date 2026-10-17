import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/features/scan/ios_camera_permission_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jp.jphacks.os_2604/camera_permission');
  final binding = TestWidgetsFlutterBinding.instance;
  late IosCameraPermissionGate gate;
  late Completer<Object?> response;

  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    response = Completer<Object?>();
    gate = IosCameraPermissionGate();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'requestCameraPermission');
      return response.future;
    });
  });
  tearDown(() {
    gate.cancel();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('allow while inactive waits for resume', () async {
    bool? allowed;
    gate.request().then((value) => allowed = value);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    response.complete(true);
    await flush();
    expect(allowed, isNull);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush();
    expect(allowed, isTrue);
  });

  test('deny is not replaced by a resume or another request', () async {
    final denied = gate.request();
    response.complete(false);
    await flush();
    expect(await denied, isFalse);
    response = Completer<Object?>()..complete(true);
    expect(await gate.request(), isTrue);
  });

  test('cancel ignores late allow and does not complete a retry', () async {
    final first = gate.request();
    await flush();
    final oldResponse = response;
    gate.cancel();
    expect(await first, isFalse);
    response = Completer<Object?>();
    bool? allowed;
    gate.request().then((value) => allowed = value);
    await flush();
    oldResponse.complete(true);
    await flush();
    expect(allowed, isNull);
    response.complete(false);
    await flush();
    expect(allowed, isFalse);
  });

  test('cancel releases the wait after allow but before resume', () async {
    final first = gate.request();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    response.complete(true);
    await flush();
    gate.cancel();
    expect(await first, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush();
    response = Completer<Object?>()..complete(true);
    expect(await gate.request(), isTrue);
  });

  test('invalid native replies and missing bridge surface as errors', () async {
    final invalid = expectLater(gate.request(), throwsStateError);
    response.complete('authorized');
    await invalid;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await expectLater(gate.request(), throwsA(isA<MissingPluginException>()));
  });
}
