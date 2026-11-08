# flutter_screen_capture example

Demo app for the plugin: capture the entire screen, a fixed area, a pixel color, plus the two live views.

```
flutter run -d windows   # or macos / linux
```

Integration test (real capture on the current desktop):

```
flutter test integration_test/capture_test.dart -d windows
```

On macOS the app needs the Screen Recording permission; the example's entitlements disable the sandbox for this reason.
