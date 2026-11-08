# flutter_screen_capture

[![Pub](https://img.shields.io/pub/v/flutter_screen_capture)](https://pub.dev/packages/flutter_screen_capture)

A plugin to capture the entire screen or part of it on desktop platforms.

|             | macOS | Windows | Linux |
|:------------|:------|:--------|:------|
| **Support** | ✅     | ✅       | ⚠️ X11 only |

## Usage

### Capture the entire screen

```dart
final area = await ScreenCapture().captureEntireScreen();
```

### Capture a specific area of the screen

```dart
final topLeftCorner = Rect.fromLTWH(0, 0, 100, 100);
final area = await ScreenCapture().captureScreenArea(topLeftCorner);
```

### Capture a single pixel color

```dart
final color = await ScreenCapture().captureScreenColor(100, 100);
```

### Widgets

There are 2 widgets you can use to see a live preview of a screen area or a pixel color.
They both display what's under the mouse cursor.

Screen area preview:

```dart
SizedBox(
  width: 72,
  height: 72,
  child: ScreenAreaLiveView(areaSize: 72 / 4),
)
```

Color live preview:

```dart
SizedBox(
  width: 48,
  height: 48,
  child: ScreenColorLiveView(),
)
```

### Advanced usage

See the [example app](https://github.com/albemala/flutter_screen_capture/tree/main/example) for a complete usage
example.

## Coordinates

All rects and points are **logical** screen coordinates, the same space returned by
`ScreenRetriever.instance.getCursorScreenPoint()`. On Windows they are converted to physical
pixels with the device pixel ratio, so display scaling (125%, 150%, ...) is handled.
macOS returns one pixel per point on Retina displays.

The returned `CapturedScreenArea` can be smaller than requested (for example when the area is
partly off-screen on macOS), so always use its `width` and `height`.
Pixels are tightly packed; `channelOrder` tells you the byte order (BGRA on macOS/Windows,
RGBA on Linux) and `getPixelColor` already handles it.

## Current limitations

- Linux works on X11 only; Wayland does not allow reading the root window.
- On Windows with several monitors that use **different** scaling factors, the conversion uses the
  scale factor of the app window, so captures on the other monitors may be offset.
- macOS uses `CGWindowListCreateImage`, which is deprecated since macOS 14 (ScreenCaptureKit is the
  replacement) and needs the Screen Recording permission.

## Projects using this package

- **[Hexee Pro](https://hexee.app/)** - Palette editor & Advanced color toolkit for designers and developers.

Feel free to submit a pull request to add your project to this list.

## Support this project

- [GitHub Sponsor](https://github.com/sponsors/albemala)
- [Buy Me A Coffee](https://www.buymeacoffee.com/albemala)

## Other projects

[All my projects](https://projects.albemala.me/)

## Credits

Created by [@albemala](https://github.com/albemala) ([Twitter](https://twitter.com/albemala))
