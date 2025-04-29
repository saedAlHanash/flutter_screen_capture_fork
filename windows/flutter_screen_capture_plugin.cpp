#include "flutter_screen_capture_plugin.h"
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "stb_image_write.h"

#include <memory>
#include <sstream>

namespace flutter_screen_capture {

    void FlutterScreenCapturePlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {
        auto channel = std::make_unique < flutter::MethodChannel < flutter::EncodableValue >> (
                registrar->messenger(),
                        "flutter_screen_capture",
                        &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<FlutterScreenCapturePlugin>();

        channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

        registrar->AddPlugin(std::move(plugin));
    }

    FlutterScreenCapturePlugin::FlutterScreenCapturePlugin() = default;

    FlutterScreenCapturePlugin::~FlutterScreenCapturePlugin() = default;

    void FlutterScreenCapturePlugin::HandleMethodCall(
            const flutter::MethodCall <flutter::EncodableValue> &method_call,
            std::unique_ptr <flutter::MethodResult<flutter::EncodableValue>> result) {

        if (method_call.method_name() == "captureScreenArea") {
            const auto &args = std::get<flutter::EncodableMap>(*method_call.arguments());
            int x = std::get<int>(args.at(flutter::EncodableValue("x")));
            int y = std::get<int>(args.at(flutter::EncodableValue("y")));
            int width = std::get<int>(args.at(flutter::EncodableValue("width")));
            int height = std::get<int>(args.at(flutter::EncodableValue("height")));

            auto compressedBytes = CaptureAndCompressScreenArea(x, y, width, height);

            flutter::EncodableMap dict;
            dict[flutter::EncodableValue("buffer")] = flutter::EncodableValue(
                    std::vector<uint8_t>(compressedBytes.begin(), compressedBytes.end()));
            dict[flutter::EncodableValue("format")] = flutter::EncodableValue("jpeg");
            result->Success(dict);
        } else {
            result->NotImplemented();
        }
    }

    std::vector <uint8_t> FlutterScreenCapturePlugin::CaptureAndCompressScreenArea(
            int x,
            int y,
            int width,
            int height) {

        HDC screen = GetDC(nullptr);
        HDC screenMem = CreateCompatibleDC(screen);
        HBITMAP dib = CreateCompatibleBitmap(screen, width, height);
        SelectObject(screenMem, dib);
        BitBlt(screenMem, 0, 0, width, height, screen, x, y, SRCCOPY);

        BITMAPINFO bi;
        bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
        bi.bmiHeader.biWidth = width;
        bi.bmiHeader.biHeight = -height; // top-down
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;
        bi.bmiHeader.biSizeImage = 0;
        bi.bmiHeader.biXPelsPerMeter = 0;
        bi.bmiHeader.biYPelsPerMeter = 0;
        bi.bmiHeader.biClrUsed = 0;
        bi.bmiHeader.biClrImportant = 0;

        std::vector <uint8_t> pixelData(width * height * 4); // BGRA

        GetDIBits(screenMem, dib, 0, height, pixelData.data(), &bi, DIB_RGB_COLORS);

        ReleaseDC(nullptr, screen);
        DeleteObject(dib);
        DeleteDC(screenMem);

        // Convert BGRA to RGB
        std::vector <uint8_t> rgbData(width * height * 3);
        for (int i = 0; i < width * height; ++i) {
            rgbData[i * 3 + 0] = pixelData[i * 4 + 2]; // R
            rgbData[i * 3 + 1] = pixelData[i * 4 + 1]; // G
            rgbData[i * 3 + 2] = pixelData[i * 4 + 0]; // B
        }

        // Compress to JPEG using stb_image_write
        std::vector <uint8_t> jpegBuffer;
        stbi_write_func *write_func = [](void *context, void *data, int size) {
            auto *buffer = reinterpret_cast<std::vector <uint8_t> *>(context);
            buffer->insert(buffer->end(), static_cast<uint8_t *>(data),
                           static_cast<uint8_t *>(data) + size);
        };

        stbi_write_jpg_to_func(write_func, &jpegBuffer, width, height, 3, rgbData.data(),
                               50); // quality 50

        return jpegBuffer;
    }

} // namespace flutter_screen_capture
