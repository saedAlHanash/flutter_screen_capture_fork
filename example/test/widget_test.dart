import 'package:flutter/services.dart';
import 'package:flutter_screen_capture_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the capture buttons', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_screen_capture'),
      (call) async => null,
    );
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Capture entire screen'), findsOneWidget);
    expect(find.text('Capture top-left 200x200'), findsOneWidget);
    expect(find.text('Pick color at (100, 100)'), findsOneWidget);
  });
}
