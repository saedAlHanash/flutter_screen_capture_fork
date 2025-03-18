import 'package:flutter/services.dart';
import 'package:flutter_screen_capture/src/captured_screen_area.dart';
import 'package:image/image.dart' as image_lib;
import 'package:screen_retriever/screen_retriever.dart';

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

  /// Captures a screen area of the main display.
  Future<CapturedScreenArea?> captureScreenArea(
    Rect rect,
  ) async {
    final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
    if (rect.isEmpty) return null;

    final correctedRect = rect;
    if (correctedRect.isEmpty) return null;

    print('''
            'width': ${correctedRect.width * primaryDisplay.scaleFactor!.toInt()},
        'height': ${correctedRect.height * primaryDisplay.scaleFactor!.toInt()},
    ''');
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'captureScreenArea',
      <String, dynamic>{
        'x': correctedRect.left.toInt(),
        'y': correctedRect.top.toInt(),
        'width': (correctedRect.width * primaryDisplay.scaleFactor!).toInt(),
        'height': (correctedRect.height * primaryDisplay.scaleFactor!).toInt(),
      },
    );
    if (result == null) return null;

    final area = CapturedScreenArea.fromJson(result);
    return _sanitizeCapturedArea(area, rect, correctedRect);
  }

  /// Captures the color of a pixel on the screen.
  Future<Color?> captureScreenColor(double x, double y) async {
    final area = await captureScreenArea(
      Rect.fromLTWH(x, y, 1, 1),
    );
    return area?.getPixelColor(0, 0);
  }
}

// Future<Rect> _sanitizeRect(Rect rect) async {
//   final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
//   return rect.intersect(
//     Rect.fromLTWH(
//       0,
//       0,
//       primaryDisplay.size.width * primaryDisplay.scaleFactor!.toDouble(),
//       primaryDisplay.size.height * primaryDisplay.scaleFactor!.toDouble(),
//     ),
//   );
// }

Future<CapturedScreenArea> _sanitizeCapturedArea(
  CapturedScreenArea area,
  Rect originalRect,
  Rect correctedRect,
) async {
  var correctedArea = area;
  return correctedArea;

  if (correctedRect != originalRect) {
    // The intersection area (between the primary display area
    // and the requested area) is smaller than the requested area.
    // Usually this happens when requesting an area close to the screen border.
    // We need to fill the captured area with black pixels,
    // where the pixels are outside the requested area.

    final originalWidth = originalRect.width.toInt();
    final originalHeight = originalRect.height.toInt();
    // Create a black image of the size of the requested area
    final emptyImage = image_lib.Image.fromBytes(
      width: originalWidth,
      height: originalHeight,
      bytes: Uint8List.fromList(
        List<int>.filled(
          originalWidth * originalHeight * 4,
          0,
        ),
      ).buffer,
    );
    // Draw the captured image on top of the black image
    final correctedImage = image_lib.compositeImage(
      emptyImage,
      area.toImage(),
      dstX: (correctedRect.left - originalRect.left).toInt(),
      dstY: (correctedRect.top - originalRect.top).toInt(),
      blend: image_lib.BlendMode.direct,
    );
    // Update the captured area with the new image
    correctedArea = correctedArea.copyWith(
      buffer: correctedImage.getBytes(
        order: correctedArea.channelOrder,
      ),
      width: originalWidth,
      height: originalHeight,
    );
  }

  return correctedArea;
}
