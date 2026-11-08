import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screen_capture/src/captured_screen_area.dart';
import 'package:flutter_screen_capture/src/screen_capture.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// A widget that displays the screen area at the cursor position.
/// The area is updated every frame.
///
/// Notes:
/// - Make sure to wrap it into a [SizedBox] to give it a size.
class ScreenAreaLiveView extends StatefulWidget {
  /// The size of the captured area in logical pixels.
  final double areaSize;

  const ScreenAreaLiveView({
    required this.areaSize,
    super.key,
  }) : assert(areaSize > 0, 'areaSize must be greater than 0');

  @override
  State<ScreenAreaLiveView> createState() => _ScreenAreaLiveViewState();
}

class _ScreenAreaLiveViewState extends State<ScreenAreaLiveView>
    with SingleTickerProviderStateMixin {
  final _plugin = ScreenCapture();
  ui.Image? _image;
  late final Ticker _ticker;

  /// True while a capture is running, so frames do not pile up
  /// platform calls faster than the platform can answer them.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => unawaited(_captureFrame()));
    _ticker.start();
  }

  Future<void> _captureFrame() async {
    if (_busy) return;
    _busy = true;
    try {
      final cursorScreenPoint =
          await ScreenRetriever.instance.getCursorScreenPoint();
      final rect = Rect.fromCircle(
        center: cursorScreenPoint,
        radius: widget.areaSize / 2,
      );
      final area = await _plugin.captureScreenArea(rect);
      if (area == null || !mounted) return;

      final image = await capturedScreenAreaToUiImage(area);
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _image;
      setState(() => _image = image);
      old?.dispose();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_screen_capture',
          context: ErrorDescription('while capturing the live screen area'),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox();
    // Nearest-neighbour scaling keeps every captured pixel a sharp square,
    // which is what a magnifier needs. One draw call instead of one per pixel.
    return RawImage(
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }
}

/// Converts a [CapturedScreenArea] into a GPU [ui.Image].
Future<ui.Image> capturedScreenAreaToUiImage(CapturedScreenArea area) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    area.buffer,
    area.width,
    area.height,
    area.isBgra ? ui.PixelFormat.bgra8888 : ui.PixelFormat.rgba8888,
    completer.complete,
    rowBytes: area.width * area.bytesPerPixel,
  );
  return completer.future;
}

/// Paints a [CapturedScreenArea] one rectangle per pixel.
///
/// Kept for backward compatibility. [ScreenAreaLiveView] now uses a single
/// [RawImage], which is much cheaper for larger areas.
class CapturedScreenAreaPainter extends CustomPainter {
  final CapturedScreenArea area;

  const CapturedScreenAreaPainter({
    required this.area,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (area.width == 0 || area.height == 0) return;
    final pixelWidth = size.width / area.width;
    final pixelHeight = size.height / area.height;
    final paint = Paint();
    for (var row = 0; row < area.height; row++) {
      for (var column = 0; column < area.width; column++) {
        paint.color = area.getPixelColor(column.toDouble(), row.toDouble());
        canvas.drawRect(
          Rect.fromLTWH(
            column * pixelWidth,
            row * pixelHeight,
            pixelWidth,
            pixelHeight,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CapturedScreenAreaPainter oldDelegate) {
    return oldDelegate.area != area;
  }
}
