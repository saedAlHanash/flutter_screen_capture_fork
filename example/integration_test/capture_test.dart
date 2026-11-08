import 'package:flutter/material.dart';
import 'package:flutter_screen_capture/flutter_screen_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real capture on this platform', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ColoredBox(color: Color(0xFF123456))));
    await tester.pump(const Duration(seconds: 1));
    final area = await ScreenCapture().captureScreenArea(const Rect.fromLTWH(10, 10, 20, 10));
    expect(area, isNotNull);
    expect(area!.width, 20);
    expect(area.height, 10);
    expect(area.buffer.length, 20 * 10 * area.bytesPerPixel);
    // ignore: avoid_print
    print('CAPTURED ${area.width}x${area.height} bpp=${area.bitsPerPixel} color=${area.getPixelColor(0, 0)}');
    final c = await ScreenCapture().captureScreenColor(15, 15);
    expect(c, isNotNull);
    final png = area.toPngImage();
    expect(png.length, greaterThan(8));
  });
}
