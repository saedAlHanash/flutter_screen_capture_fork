import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_screen_capture/src/captured_screen_area.dart';

/// A widget that displays a captured screen area as an image.
///
/// The PNG is encoded once per [area] instead of on every rebuild.
class CapturedScreenAreaView extends StatefulWidget {
  final CapturedScreenArea area;

  const CapturedScreenAreaView({
    required this.area,
    super.key,
  });

  @override
  State<CapturedScreenAreaView> createState() => _CapturedScreenAreaViewState();
}

class _CapturedScreenAreaViewState extends State<CapturedScreenAreaView> {
  late Uint8List _png = widget.area.toPngImage();

  @override
  void didUpdateWidget(CapturedScreenAreaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area != widget.area) {
      _png = widget.area.toPngImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.memory(_png, gaplessPlayback: true);
  }
}
