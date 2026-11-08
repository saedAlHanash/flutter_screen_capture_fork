import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screen_capture/src/screen_capture.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// A widget that displays the color of the screen pixel at the cursor position.
/// The color is updated every frame.
///
/// Notes:
/// - Make sure to wrap it into a [SizedBox] to give it a size.
class ScreenColorLiveView extends StatefulWidget {
  const ScreenColorLiveView({
    super.key,
  });

  @override
  State<ScreenColorLiveView> createState() => _ScreenColorLiveViewState();
}

class _ScreenColorLiveViewState extends State<ScreenColorLiveView>
    with SingleTickerProviderStateMixin {
  final _plugin = ScreenCapture();
  Color _color = const Color(0xFF000000);
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
      final color = await _plugin.captureScreenColor(
        cursorScreenPoint.dx,
        cursorScreenPoint.dy,
      );
      if (color == null || !mounted || color == _color) return;
      setState(() => _color = color);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_screen_capture',
          context: ErrorDescription('while capturing the live screen color'),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _color);
  }
}
