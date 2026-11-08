import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter_screen_capture/src/captured_screen_area.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Captures pixels from the screen.
///
/// All rectangles and points passed to this class are in **logical** screen
/// coordinates, the same coordinate space returned by
/// `ScreenRetriever.instance.getCursorScreenPoint()`.
///
/// On Windows the logical coordinates are converted to physical pixels using
/// the device pixel ratio, so the capture is correct when display scaling
/// (125%, 150%, ...) is enabled. On macOS the native side already works in
/// points and scales Retina captures down by itself.
///
/// Parts of the requested area that are outside every display are returned
/// as black pixels (Windows) or are cropped by the OS (macOS/Linux); always
/// read [CapturedScreenArea.width] and [CapturedScreenArea.height] instead of
/// assuming the requested size.
class ScreenCapture {
  final _methodChannel = const MethodChannel('flutter_screen_capture');

  /// Captures the entire screen area of the main display.
  Future<CapturedScreenArea?> captureEntireScreen() async {
    final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
    return captureScreenArea(
      Rect.fromLTWH(
        0,
        0,
        primaryDisplay.size.width,
        primaryDisplay.size.height,
      ),
    );
  }

  /// Captures a screen area, given in logical screen coordinates.
  Future<CapturedScreenArea?> captureScreenArea(Rect rect) async {
    if (rect.isEmpty || !rect.isFinite) return null;

    final scale = await _logicalToNativeScale();
    final x = (rect.left * scale).floor();
    final y = (rect.top * scale).floor();
    // Round the size up so a 1x1 logical request never becomes 0x0.
    final width = (rect.width * scale).ceil();
    final height = (rect.height * scale).ceil();
    if (width <= 0 || height <= 0) return null;

    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'captureScreenArea',
      <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      },
    );
    if (result == null) return null;

    final area = CapturedScreenArea.fromJson(result);
    if (area.width <= 0 || area.height <= 0) return null;
    if (area.buffer.length < area.width * area.height * area.bytesPerPixel) {
      return null;
    }
    return area;
  }

  /// Captures the color of a pixel on the screen, given in logical
  /// screen coordinates.
  Future<Color?> captureScreenColor(double x, double y) async {
    final area = await captureScreenArea(Rect.fromLTWH(x, y, 1, 1));
    if (area == null) return null;
    return area.getPixelColor(0, 0);
  }
}

/// The factor between the logical coordinates used by the Dart API and the
/// coordinates expected by the native implementation.
Future<double> _logicalToNativeScale() async {
  if (!Platform.isWindows) return 1;

  // screen_retriever (Windows) converts the physical cursor position to
  // logical coordinates by dividing by the Flutter view's devicePixelRatio,
  // so multiplying by the same value is the exact inverse.
  final views = PlatformDispatcher.instance.views;
  if (views.isNotEmpty) {
    final ratio = views.first.devicePixelRatio;
    if (ratio > 0) return ratio;
  }

  final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
  final ratio = primaryDisplay.scaleFactor?.toDouble() ?? 1;
  return ratio > 0 ? ratio : 1;
}
