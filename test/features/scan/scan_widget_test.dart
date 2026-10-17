import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:os_2604/features/scan/scan_widget.dart';
import 'package:os_2604/models/scan_contract.dart';

class FakeService implements HealthScanService {
  int cancels = 0;
  @override
  ScanProgress get currentProgress => const ScanProgress(phase: ScanPhase.idle);
  @override
  Stream<ScanProgress> get progress => const Stream.empty();
  @override
  Future<void> cancelScan() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<ScanOutcome> startHealthScan() async => const ScanFailure(
    reason: ScanFailureReason.cameraUnavailable,
    elapsed: Duration.zero,
  );
}

void main() {
  testWidgets('placeholder and overlay do not open a camera', (tester) async {
    final service = FakeService();
    final preview = ValueNotifier<CameraController?>(null);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScanWidget(
          service: service,
          preview: preview,
          placeholder: const Text('準備中'),
          overlay: const Text('顔ガイド'),
        ),
      ),
    );
    expect(find.text('準備中'), findsOneWidget);
    expect(find.text('顔ガイド'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(service.cancels, greaterThan(0));
    preview.dispose();
  });

  testWidgets('leaving foreground cancels; resume never auto-restarts', (
    tester,
  ) async {
    final service = FakeService();
    final preview = ValueNotifier<CameraController?>(null);
    await tester.pumpWidget(
      ScanWidget(
        service: service,
        preview: preview,
        placeholder: const SizedBox(),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(service.cancels, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.cancels, 1);
    await tester.pumpWidget(const SizedBox());
    preview.dispose();
  });
}
