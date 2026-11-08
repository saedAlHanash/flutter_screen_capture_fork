import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_screen_capture/flutter_screen_capture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a 2x1 area with a red pixel and a blue pixel, written in the
/// channel order of the platform the test runs on.
CapturedScreenArea _redBlueArea() {
  final probe = CapturedScreenArea(
    buffer: Uint8List(0),
    width: 0,
    height: 0,
    bitsPerPixel: 32,
    bytesPerPixel: 4,
  );
  final bytes = probe.isBgra
      ? <int>[0, 0, 255, 255, 255, 0, 0, 255] // B G R A
      : <int>[255, 0, 0, 255, 0, 0, 255, 255]; // R G B A
  return CapturedScreenArea(
    buffer: Uint8List.fromList(bytes),
    width: 2,
    height: 1,
    bitsPerPixel: 32,
    bytesPerPixel: 4,
  );
}

void main() {
  group('CapturedScreenArea.fromJson', () {
    test('uses a Uint8List buffer without copying it', () {
      final buffer = Uint8List.fromList([1, 2, 3, 4]);
      final area = CapturedScreenArea.fromJson({
        'buffer': buffer,
        'width': 1,
        'height': 1,
        'bitsPerPixel': 32,
        'bytesPerPixel': 4,
      });
      expect(identical(area.buffer, buffer), isTrue);
      expect(area.width, 1);
      expect(area.bytesPerPixel, 4);
    });

    test('accepts a plain List<int> buffer', () {
      final area = CapturedScreenArea.fromJson(const {
        'buffer': <Object?>[1, 2, 3, 4],
        'width': 1,
        'height': 1,
        'bitsPerPixel': 32,
        'bytesPerPixel': 4,
      });
      expect(area.buffer, [1, 2, 3, 4]);
    });

    test('missing fields fall back to empty values', () {
      final area = CapturedScreenArea.fromJson(const {});
      expect(area.buffer, isEmpty);
      expect(area.width, 0);
      expect(area.aspectRatio, 0);
    });
  });

  group('CapturedScreenArea.getPixelColor', () {
    test('reads red and blue correctly for the platform channel order', () {
      final area = _redBlueArea();
      expect(area.getPixelColor(0, 0), const Color(0xFFFF0000));
      expect(area.getPixelColor(1, 0), const Color(0xFF0000FF));
    });

    test('throws for coordinates outside the area', () {
      final area = _redBlueArea();
      expect(() => area.getPixelColor(2, 0), throwsRangeError);
      expect(() => area.getPixelColor(0, -1), throwsRangeError);
    });
  });

  test('toImage keeps red and blue in the right place', () {
    final image = _redBlueArea().toImage();
    final red = image.getPixel(0, 0);
    final blue = image.getPixel(1, 0);
    expect([red.r, red.g, red.b], [255, 0, 0]);
    expect([blue.r, blue.g, blue.b], [0, 0, 255]);
  });

  test('toPngImage produces a PNG', () {
    final png = _redBlueArea().toPngImage();
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
