import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:os_2604/features/scan/scan_widget.dart';
import 'package:os_2604/models/scan_contract.dart';

class FakeService implements HealthScanService {
  int cancels = 0;
  ScanPhase phase = ScanPhase.idle;
  @override
  ScanProgress get currentProgress => ScanProgress(phase: phase);
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
  for (final ratio in [3 / 4, 9 / 16, 4 / 3]) {
    testWidgets('preview keeps $ratio aspect ratio in a tight oval guide', (
      tester,
    ) async {
      const imageKey = ValueKey('camera-image');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 240,
              height: 320,
              child: CameraPreviewViewport(
                aspectRatio: ratio,
                child: const SizedBox.expand(key: imageKey),
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(imageKey));
      expect(size.width / size.height, closeTo(ratio, 0.000001));
      final fit = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fit.fit, BoxFit.cover);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'permission dialog inactivity waits, backgrounding still cancels',
    (tester) async {
      final service = FakeService()..phase = ScanPhase.requestingPermission;
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
      expect(service.cancels, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.cancels, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(service.cancels, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      preview.dispose();
    },
  );

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
    final service = FakeService()..phase = ScanPhase.measuring;
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
