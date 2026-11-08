import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_screen_capture/flutter_screen_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_screen_capture');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call) reply = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, Object> opaqueArea(int width, int height) => {
        'buffer': Uint8List.fromList(
          List<int>.filled(width * height * 4, 255),
        ),
        'width': width,
        'height': height,
        'bitsPerPixel': 32,
        'bytesPerPixel': 4,
      };

  test('empty and non-finite rects never reach the platform', () async {
    final capture = ScreenCapture();
    expect(await capture.captureScreenArea(Rect.zero), isNull);
    expect(
      await capture.captureScreenArea(
        const Rect.fromLTWH(0, 0, double.infinity, 10),
      ),
      isNull,
    );
    expect(calls, isEmpty);
  });

  test(
    'passes logical coordinates through unchanged off Windows',
    () async {
      reply = (_) => opaqueArea(10, 5);
      final area = await ScreenCapture().captureScreenArea(
        const Rect.fromLTWH(3.7, 4.2, 10, 5),
      );
      expect(area, isNotNull);
      expect(calls.single.method, 'captureScreenArea');
      expect(calls.single.arguments, {
        'x': 3,
        'y': 4,
        'width': 10,
        'height': 5,
      });
    },
    skip: Platform.isWindows ? 'Windows scales by devicePixelRatio' : false,
  );

  test('a 1x1 request is never rounded down to 0x0', () async {
    reply = (_) => opaqueArea(1, 1);
    await ScreenCapture().captureScreenArea(
      const Rect.fromLTWH(0, 0, 0.5, 0.5),
    );
    final args = calls.single.arguments as Map;
    expect(args['width'], greaterThanOrEqualTo(1));
    expect(args['height'], greaterThanOrEqualTo(1));
  });

  test('returns null when the platform returns a short buffer', () async {
    reply = (_) => {
          'buffer': Uint8List(4),
          'width': 10,
          'height': 10,
          'bitsPerPixel': 32,
          'bytesPerPixel': 4,
        };
    expect(
      await ScreenCapture().captureScreenArea(
        const Rect.fromLTWH(0, 0, 10, 10),
      ),
      isNull,
    );
  });

  test('captureScreenColor returns an opaque color', () async {
    reply = (_) => opaqueArea(1, 1);
    final color = await ScreenCapture().captureScreenColor(5, 5);
    expect(color, const Color(0xFFFFFFFF));
  });

  test('captureScreenColor returns null when nothing was captured', () async {
    reply = (_) => null;
    expect(await ScreenCapture().captureScreenColor(5, 5), isNull);
  });
}
