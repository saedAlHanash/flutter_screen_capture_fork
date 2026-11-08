## 1.3.0

Fixes
- Windows: x, y, width and height are now all converted from logical to physical pixels, so captures are correct with display scaling (125%, 150%, ...). Previously only width/height were scaled, so the area was shifted away from the cursor.
- macOS: no longer multiplies the size by the scale factor (the native side already handles Retina), which captured an area twice as large.
- macOS: output is always tightly packed BGRA, so row padding can no longer shift pixels.
- Windows: the alpha byte returned by GDI is forced to 255; colors were often fully transparent.
- Colors: `getPixelColor` and `toImage`/`toPngImage` now use the real per-platform channel order (BGRA on macOS/Windows, RGBA on Linux). Red and blue were swapped in Windows PNGs and in Linux pixel colors.
- `captureScreenArea` returns `null` instead of throwing for empty, non-finite or failed captures; a 1x1 request can no longer round down to 0x0.
- No more crash when `scaleFactor` is `null`.
- Live views no longer call `setState` after `dispose`.

Native
- Windows: argument validation, GDI error checks, the old bitmap is restored before deletion, errors are reported to Dart.
- Linux: fixed a pixbuf leak and a method-response leak, null checks, argument validation, correct `bitsPerPixel` (32), tight row packing.

Performance
- `ScreenAreaLiveView` draws one `RawImage` instead of one rectangle per pixel.
- Live views skip a frame while the previous capture is still running, instead of piling up platform calls.
- `ScreenColorLiveView` only rebuilds when the color changes.
- `CapturedScreenAreaView` encodes the PNG once per area instead of on every build.
- The captured buffer is no longer copied element by element when decoding.
- No extra `getPrimaryDisplay` platform call on every capture.

Maintenance
- Removed dead clipping/padding code.
- Filled in the podspec metadata, minimum macOS 10.14 (same as Flutter).
- Added unit tests.

## 1.2.3

- Updated funding information

## 1.2.2

- Updated readme

## 1.2.1

- Upgraded dependencies
- Updated example macOS config

## 1.2.0

- Targeting Dart 3.2 and Flutter 3.16
- Upgraded dependencies
- Fixed linter issues

## 1.1.0

- Targeting Dart 2.19 and Flutter 3.7
- Upgraded dependencies
- Fixed crash when capturing area outside of primary screen
- Targeting min macOS 10.14 in example

## 1.0.2

- Removed homepage link from pubspec file

## 1.0.1

- Fixed warnings

## 1.0.0

* Capture screen area on macOS
* Capture screen area on Windows
