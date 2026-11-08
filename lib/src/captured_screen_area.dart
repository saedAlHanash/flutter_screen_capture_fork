import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image_lib;

/// Raw pixels of a captured screen area.
///
/// [buffer] is tightly packed: `width * bytesPerPixel` bytes per row, no row
/// padding. The channel order depends on the platform, see [channelOrder].
@immutable
class CapturedScreenArea {
  final Uint8List buffer;
  final int width;
  final int height;
  final int bitsPerPixel;
  final int bytesPerPixel;

  double get aspectRatio => height == 0 ? 0 : width / height;

  const CapturedScreenArea({
    required this.buffer,
    required this.width,
    required this.height,
    required this.bitsPerPixel,
    required this.bytesPerPixel,
  });

  factory CapturedScreenArea.fromJson(Map<Object?, Object?> json) {
    final rawBuffer = json['buffer'];
    final Uint8List buffer;
    if (rawBuffer is Uint8List) {
      // The standard method codec already delivers a Uint8List:
      // use it directly instead of copying it element by element.
      buffer = rawBuffer;
    } else if (rawBuffer is List) {
      buffer = Uint8List.fromList(rawBuffer.cast<int>());
    } else {
      buffer = Uint8List(0);
    }
    return CapturedScreenArea(
      buffer: buffer,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      bitsPerPixel: json['bitsPerPixel'] as int? ?? 0,
      bytesPerPixel: json['bytesPerPixel'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'buffer': buffer,
      'width': width,
      'height': height,
      'bitsPerPixel': bitsPerPixel,
      'bytesPerPixel': bytesPerPixel,
    };
  }

  /// The byte order of the four channels in [buffer].
  ///
  /// - macOS (CoreGraphics, little-endian premultiplied-first): BGRA
  /// - Windows (GDI `GetDIBits`, 32-bit `BI_RGB`): BGRA
  /// - Linux (`GdkPixbuf` with alpha): RGBA
  image_lib.ChannelOrder get channelOrder {
    if (Platform.isMacOS || Platform.isWindows) {
      return image_lib.ChannelOrder.bgra;
    }
    return image_lib.ChannelOrder.rgba;
  }

  /// Whether [buffer] stores blue before red.
  bool get isBgra => channelOrder == image_lib.ChannelOrder.bgra;

  image_lib.Image toImage() {
    return image_lib.Image.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(buffer).buffer,
      numChannels: 4,
      order: channelOrder,
    );
  }

  Uint8List toPngImage() {
    return Uint8List.fromList(image_lib.encodePng(toImage(), level: 0));
  }

  Color getPixelColor(double x, double y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Pixel coordinates out of range');
    }
    final index = (y.toInt() * width + x.toInt()) * bytesPerPixel;
    final c0 = buffer[index];
    final g = buffer[index + 1];
    final c2 = buffer[index + 2];
    final a = bytesPerPixel >= 4 ? buffer[index + 3] : 0xFF;
    final r = isBgra ? c2 : c0;
    final b = isBgra ? c0 : c2;
    return Color.fromARGB(a, r, g, b);
  }

  CapturedScreenArea copyWith({
    Uint8List? buffer,
    int? width,
    int? height,
    int? bitsPerPixel,
    int? bytesPerPixel,
  }) {
    return CapturedScreenArea(
      buffer: buffer ?? this.buffer,
      width: width ?? this.width,
      height: height ?? this.height,
      bitsPerPixel: bitsPerPixel ?? this.bitsPerPixel,
      bytesPerPixel: bytesPerPixel ?? this.bytesPerPixel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturedScreenArea &&
          runtimeType == other.runtimeType &&
          buffer == other.buffer &&
          width == other.width &&
          height == other.height &&
          bitsPerPixel == other.bitsPerPixel &&
          bytesPerPixel == other.bytesPerPixel;

  @override
  int get hashCode =>
      buffer.hashCode ^ //
      width.hashCode ^
      height.hashCode ^
      bitsPerPixel.hashCode ^
      bytesPerPixel.hashCode;
}
