import 'dart:typed_data';

/// Formats accepted by the brightness sampler, not ML Kit input formats.
enum LuminanceFormat { yPlane, bgra8888 }

/// A non-empty region in the raw image buffer's coordinates.
///
/// Transform rotated/mirrored detector coordinates before constructing this.
class FrameRegion {
  const FrameRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}

/// Returns mean brightness in 0..255, or null for invalid frame metadata.
///
/// For YUV/NV21, pass only the Y plane with its actual row stride. BGRA uses
/// weighted RGB brightness and ignores alpha. These formats are not calibrated
/// to the same brightness scale; choose thresholds using the target device.
/// This synchronous function neither retains nor persists [bytes].
double? meanFrameLuminance({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  required LuminanceFormat format,
  FrameRegion? region,
}) {
  final bytesPerPixel = format == LuminanceFormat.bgra8888 ? 4 : 1;
  if (width <= 0 ||
      height <= 0 ||
      bytesPerRow <= 0 ||
      width > bytes.length ~/ bytesPerPixel) {
    return null;
  }
  final pixelRowBytes = width * bytesPerPixel;
  // Divide before multiplying to reject oversized metadata without overflow.
  if (bytesPerRow < pixelRowBytes ||
      height - 1 > (bytes.length - pixelRowBytes) ~/ bytesPerRow) {
    return null;
  }

  final area =
      region ?? FrameRegion(left: 0, top: 0, width: width, height: height);
  if (area.left < 0 ||
      area.top < 0 ||
      area.width <= 0 ||
      area.height <= 0 ||
      area.left > width ||
      area.top > height ||
      area.width > width - area.left ||
      area.height > height - area.top) {
    return null;
  }

  var sum = 0.0;
  for (var y = area.top; y < area.top + area.height; y++) {
    for (var x = area.left; x < area.left + area.width; x++) {
      final offset = y * bytesPerRow + x * bytesPerPixel;
      if (format == LuminanceFormat.yPlane) {
        sum += bytes[offset];
      } else {
        sum +=
            0.0722 * bytes[offset] +
            0.7152 * bytes[offset + 1] +
            0.2126 * bytes[offset + 2];
      }
    }
  }
  return (sum / (area.width * area.height)).clamp(0.0, 255.0);
}
