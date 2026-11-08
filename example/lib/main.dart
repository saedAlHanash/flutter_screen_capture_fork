import 'package:flutter/material.dart';
import 'package:flutter_screen_capture/flutter_screen_capture.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_screen_capture example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _capture = ScreenCapture();
  CapturedScreenArea? _area;
  Color? _color;
  String _status = 'Nothing captured yet.';
  bool _busy = false;

  Future<void> _run(String name, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final stopwatch = Stopwatch()..start();
    try {
      await action();
      _status = '$name finished in ${stopwatch.elapsedMilliseconds} ms';
    } on Object catch (error) {
      _status = '$name failed: $error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureEntireScreen() => _run('Entire screen', () async {
        final area = await _capture.captureEntireScreen();
        if (!mounted) return;
        setState(() => _area = area);
      });

  Future<void> _captureTopLeft() => _run('Top-left 200x200', () async {
        final area = await _capture.captureScreenArea(
          const Rect.fromLTWH(0, 0, 200, 200),
        );
        if (!mounted) return;
        setState(() => _area = area);
      });

  Future<void> _captureColor() => _run('Pixel (100, 100)', () async {
        final color = await _capture.captureScreenColor(100, 100);
        if (!mounted) return;
        setState(() => _color = color);
      });

  @override
  Widget build(BuildContext context) {
    final area = _area;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_screen_capture')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _captureEntireScreen,
                  child: const Text('Capture entire screen'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _captureTopLeft,
                  child: const Text('Capture top-left 200x200'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _captureColor,
                  child: const Text('Pick color at (100, 100)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_status),
            if (area != null)
              Text('${area.width} x ${area.height} px, '
                  '${area.bitsPerPixel} bpp'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Live cursor color: '),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: ScreenColorLiveView(),
                ),
                const SizedBox(width: 24),
                const Text('Live magnifier: '),
                const SizedBox(
                  width: 96,
                  height: 96,
                  child: ScreenAreaLiveView(areaSize: 24),
                ),
                if (_color != null) ...[
                  const SizedBox(width: 24),
                  const Text('Picked: '),
                  Container(width: 32, height: 32, color: _color),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: area == null
                  ? const Center(child: Text('Press a button to capture.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: CapturedScreenAreaView(area: area),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
