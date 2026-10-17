import 'dart:typed_data';

import 'package:test/test.dart';

import '../../../lib/features/scan/frame_luminance.dart';

void main() {
  double? sampleY(
    List<int> bytes, {
    int width = 2,
    int height = 2,
    int bytesPerRow = 2,
    FrameRegion? region,
  }) => meanFrameLuminance(
    bytes: Uint8List.fromList(bytes),
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    format: LuminanceFormat.yPlane,
    region: region,
  );

  test('Y plane excludes row padding, including an unpadded final row', () {
    expect(sampleY([10, 20, 255, 255, 30, 40], bytesPerRow: 4), 25);
  });

  test('region excludes a bright background outside the face', () {
    expect(
      sampleY([
        255,
        10,
        255,
        30,
      ], region: const FrameRegion(left: 1, top: 0, width: 1, height: 2)),
      20,
    );
  });

  test('zero is measured darkness; invalid input is null', () {
    expect(sampleY([0, 0, 0, 0]), 0);
    expect(sampleY([]), isNull);
    expect(sampleY([10, 20, 30]), isNull);
  });

  test('invalid dimensions and row strides are rejected', () {
    expect(sampleY([0, 0, 0, 0], width: 0), isNull);
    expect(sampleY([0, 0, 0, 0], width: -1), isNull);
    expect(sampleY([0, 0, 0, 0], height: 0), isNull);
    expect(sampleY([0, 0, 0, 0], bytesPerRow: 1), isNull);
    expect(sampleY([0, 0, 0, 0], bytesPerRow: -1), isNull);
  });

  test('invalid regions are rejected rather than clamped', () {
    for (final region in [
      const FrameRegion(left: -1, top: 0, width: 1, height: 1),
      const FrameRegion(left: 0, top: -1, width: 1, height: 1),
      const FrameRegion(left: 0, top: 0, width: 0, height: 1),
      const FrameRegion(left: 0, top: 0, width: 1, height: -1),
      const FrameRegion(left: 1, top: 0, width: 2, height: 1),
      const FrameRegion(left: 0, top: 1, width: 1, height: 2),
    ]) {
      expect(sampleY([0, 0, 0, 0], region: region), isNull);
    }
  });

  test('oversized metadata cannot overflow buffer and region checks', () {
    const huge = 0x7fffffffffffffff;
    expect(sampleY([0, 0, 0, 0], width: huge), isNull);
    expect(sampleY([0, 0, 0, 0], height: huge), isNull);
    expect(sampleY([0, 0, 0, 0], bytesPerRow: huge), isNull);
    expect(
      sampleY([
        0,
        0,
        0,
        0,
      ], region: const FrameRegion(left: huge, top: 0, width: huge, height: 1)),
      isNull,
    );
  });

  double? sampleBgra(List<int> bytes, {int bytesPerRow = 4}) =>
      meanFrameLuminance(
        bytes: Uint8List.fromList(bytes),
        width: 1,
        height: 1,
        bytesPerRow: bytesPerRow,
        format: LuminanceFormat.bgra8888,
      );

  test('BGRA channel order and weights are correct', () {
    expect(sampleBgra([255, 0, 0, 255]), closeTo(18.411, 0.0001));
    expect(sampleBgra([0, 255, 0, 255]), closeTo(182.376, 0.0001));
    expect(sampleBgra([0, 0, 255, 255]), closeTo(54.213, 0.0001));
  });

  test('BGRA ignores alpha and preserves black and white', () {
    expect(sampleBgra([0, 0, 0, 255]), 0);
    expect(sampleBgra([255, 255, 255, 0]), closeTo(255, 0.0001));
    expect(sampleBgra([20, 40, 80, 0]), sampleBgra([20, 40, 80, 255]));
  });

  test('BGRA padding and region offsets use four bytes per pixel', () {
    final bytes = Uint8List.fromList([
      255,
      255,
      255,
      255,
      10,
      10,
      10,
      255,
      255,
      255,
      255,
      255,
      255,
      255,
      255,
      255,
      30,
      30,
      30,
      255,
    ]);
    expect(
      meanFrameLuminance(
        bytes: bytes,
        width: 2,
        height: 2,
        bytesPerRow: 12,
        format: LuminanceFormat.bgra8888,
        region: const FrameRegion(left: 1, top: 0, width: 1, height: 2),
      ),
      closeTo(20, 0.0001),
    );
  });

  test('BGRA rejects truncated buffers and short rows', () {
    expect(sampleBgra([0, 0, 0]), isNull);
    expect(sampleBgra([0, 0, 0, 0], bytesPerRow: 3), isNull);
  });
}
