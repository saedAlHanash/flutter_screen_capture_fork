#include "flutter_screen_capture_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_screen_capture {

// static
    void FlutterScreenCapturePlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {
        auto channel = std::make_unique < flutter::MethodChannel < flutter::EncodableValue >> (
                registrar->messenger(),
                        "flutter_screen_capture",
                        &flutter::StandardMethodCodec::GetInstance()
        );

        auto plugin = std::make_unique<FlutterScreenCapturePlugin>();

        channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    HandleMethodCall(call, std::move(result));
                }
        );

        registrar->AddPlugin(std::move(plugin));
    }

    FlutterScreenCapturePlugin::FlutterScreenCapturePlugin() = default;

    FlutterScreenCapturePlugin::~FlutterScreenCapturePlugin() = default;

    namespace {

    // Reads an integer argument. The standard codec sends small ints as
    // int32 and large ones as int64, so accept both.
    bool GetIntArg(const flutter::EncodableMap &args, const char *key, int &out) {
        auto it = args.find(flutter::EncodableValue(key));
        if (it == args.end()) return false;
        if (const auto *v32 = std::get_if<int32_t>(&it->second)) {
            out = *v32;
            return true;
        }
        if (const auto *v64 = std::get_if<int64_t>(&it->second)) {
            out = static_cast<int>(*v64);
            return true;
        }
        return false;
    }

    }  // namespace

    void FlutterScreenCapturePlugin::HandleMethodCall(
            const flutter::MethodCall <flutter::EncodableValue> &method_call,
            std::unique_ptr <flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name() != "captureScreenArea") {
            result->NotImplemented();
            return;
        }

        const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        int x = 0, y = 0, width = 0, height = 0;
        if (args == nullptr ||
            !GetIntArg(*args, "x", x) ||
            !GetIntArg(*args, "y", y) ||
            !GetIntArg(*args, "width", width) ||
            !GetIntArg(*args, "height", height)) {
            result->Error("INVALID_ARGUMENTS", "Invalid arguments");
            return;
        }
        if (width <= 0 || height <= 0) {
            result->Error("INVALID_ARGUMENTS", "width and height must be greater than 0");
            return;
        }

        CapturedScreenArea capturedScreenArea;
        if (!CaptureScreenArea(x, y, width, height, capturedScreenArea)) {
            result->Error("CAPTURE_FAILED", "Unable to capture the screen area");
            return;
        }

        flutter::EncodableMap dict;
        dict[flutter::EncodableValue("buffer")] = flutter::EncodableValue(
                std::move(capturedScreenArea.buffer));
        dict[flutter::EncodableValue("width")] = flutter::EncodableValue(
                capturedScreenArea.width);
        dict[flutter::EncodableValue("height")] = flutter::EncodableValue(
                capturedScreenArea.height);
        dict[flutter::EncodableValue("bitsPerPixel")] = flutter::EncodableValue(
                capturedScreenArea.bitsPerPixel);
        dict[flutter::EncodableValue("bytesPerPixel")] = flutter::EncodableValue(
                capturedScreenArea.bytesPerPixel);
        result->Success(flutter::EncodableValue(std::move(dict)));
    }

    bool FlutterScreenCapturePlugin::CaptureScreenArea(
            int x,
            int y,
            int width,
            int height,
            CapturedScreenArea &out) {
        // x, y, width and height are physical pixels in virtual-screen
        // coordinates (the Dart side converts from logical coordinates).
        HDC screen = GetDC(nullptr);
        if (screen == nullptr) return false;

        HDC screenMem = CreateCompatibleDC(screen);
        HBITMAP dib = screenMem ? CreateCompatibleBitmap(screen, width, height) : nullptr;
        if (screenMem == nullptr || dib == nullptr) {
            if (dib) DeleteObject(dib);
            if (screenMem) DeleteDC(screenMem);
            ReleaseDC(nullptr, screen);
            return false;
        }

        HGDIOBJ oldBitmap = SelectObject(screenMem, dib);
        // Areas outside every monitor stay black. CAPTUREBLT is deliberately
        // not used: with DWM the screen DC already contains layered windows,
        // and CAPTUREBLT makes the mouse cursor flicker when called every frame.
        const BOOL copied = BitBlt(screenMem, 0, 0, width, height, screen, x, y, SRCCOPY);
        // The bitmap must be deselected before GetDIBits / DeleteObject.
        SelectObject(screenMem, oldBitmap);

        BITMAPINFO bi = {};
        bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
        bi.bmiHeader.biWidth = width;
        bi.bmiHeader.biHeight = -height; // Top-down rows
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        const size_t byteCount = static_cast<size_t>(width) * static_cast<size_t>(height) * 4;
        out.buffer.assign(byteCount, 0);
        out.width = width;
        out.height = height;
        out.bitsPerPixel = 32;
        out.bytesPerPixel = 4;

        const int lines = copied
                ? GetDIBits(screenMem, dib, 0, height, out.buffer.data(), &bi, DIB_RGB_COLORS)
                : 0;

        DeleteObject(dib);
        DeleteDC(screenMem);
        ReleaseDC(nullptr, screen);

        if (lines != height) return false;

        // GDI leaves the 4th byte of a 32-bit BI_RGB bitmap undefined (usually 0),
        // which Dart would read as a fully transparent colour. Force it opaque.
        for (size_t i = 3; i < byteCount; i += 4) {
            out.buffer[i] = 0xFF;
        }
        return true;
    }

}  // namespace flutter_screen_capture
