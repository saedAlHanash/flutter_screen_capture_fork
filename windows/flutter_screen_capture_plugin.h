#include "flutter_screen_capture_plugin.h"
#include <windows.h>
#include <wincodec.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <vector>

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
            auto x = std::get<int>(args.at(flutter::EncodableValue("x")));
            auto y = std::get<int>(args.at(flutter::EncodableValue("y")));
            auto width = std::get<int>(args.at(flutter::EncodableValue("width")));
            auto height = std::get<int>(args.at(flutter::EncodableValue("height")));

            CapturedScreenArea capturedScreenArea = CaptureScreenArea(x, y, width, height);

            flutter::EncodableMap dict;
            dict[flutter::EncodableValue("buffer")] = flutter::EncodableValue(
                    capturedScreenArea.buffer);
            dict[flutter::EncodableValue("width")] = flutter::EncodableValue(
                    capturedScreenArea.width);
            dict[flutter::EncodableValue("height")] = flutter::EncodableValue(
                    capturedScreenArea.height);
            dict[flutter::EncodableValue("bitsPerPixel")] = flutter::EncodableValue(
                    capturedScreenArea.bitsPerPixel);
            dict[flutter::EncodableValue("bytesPerPixel")] = flutter::EncodableValue(
                    capturedScreenArea.bytesPerPixel);
            dict[flutter::EncodableValue("isCompressed")] = flutter::EncodableValue(
                    capturedScreenArea.isCompressed);
            result->Success(dict);
        } else {
            result->NotImplemented();
        }
    }

    CapturedScreenArea FlutterScreenCapturePlugin::CaptureScreenArea(
            int x,
            int y,
            int width,
            int height) {
        // 1. التقاط الصورة من الشاشة
        HDC screen = GetDC(nullptr);
        HDC screenMem = CreateCompatibleDC(screen);
        HBITMAP dib = CreateCompatibleBitmap(screen, width, height);
        SelectObject(screenMem, dib);
        BitBlt(screenMem, 0, 0, width, height, screen, x, y, SRCCOPY);

        // 2. الحصول على بيانات الصورة الخام
        BITMAPINFO bi = {0};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = width;
        bi.bmiHeader.biHeight = -height;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        std::vector <uint8_t> rawBuffer(width * height * 4);
        GetDIBits(screenMem, dib, 0, height, rawBuffer.data(), &bi, DIB_RGB_COLORS);

        // 3. ضغط الصورة
        std::vector <uint8_t> compressedBuffer;
        IWICImagingFactory *pFactory = nullptr;
        IWICBitmapEncoder *pEncoder = nullptr;
        IWICBitmapFrameEncode *pFrame = nullptr;
        IStream *pMemStream = nullptr;

        HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        hr = CoCreateInstance(CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&pFactory));

        // إنشاء تيار في الذاكرة
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, 0);
        hr = CreateStreamOnHGlobal(hMem, TRUE, &pMemStream);

        // إنشاء مشفر PNG
        hr = pFactory->CreateEncoder(CLSID_WICPngEncoder, NULL, &pEncoder);
        hr = pEncoder->Initialize(pMemStream, WICBitmapEncoderNoCache);

        // إضافة إطار الصورة
        hr = pEncoder->CreateNewFrame(&pFrame, NULL);
        hr = pFrame->Initialize(NULL);
        hr = pFrame->SetSize(width, height);

        WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
        hr = pFrame->SetPixelFormat(&format);
        hr = pFrame->WritePixels(height, width * 4, static_cast<UINT>(rawBuffer.size()),
                                 rawBuffer.data());
        hr = pFrame->Commit();
        hr = pEncoder->Commit();

        // الحصول على البيانات المضغوطة
        STATSTG stats = {0};
        hr = pMemStream->Stat(&stats, STATFLAG_NONAME);
        compressedBuffer.resize(stats.cbSize.LowPart);
        LARGE_INTEGER li = {0};
        hr = pMemStream->Seek(li, STREAM_SEEK_SET, NULL);
        ULONG read;
        hr = pMemStream->Read(compressedBuffer.data(), static_cast<ULONG>(compressedBuffer.size()),
                              &read);

        // تحرير الموارد
        if (pFrame) pFrame->Release();
        if (pEncoder) pEncoder->Release();
        if (pMemStream) pMemStream->Release();
        if (pFactory) pFactory->Release();
        GlobalFree(hMem);
        CoUninitialize();

        // تحرير موارد التقاط الشاشة
        ReleaseDC(nullptr, screen);
        DeleteObject(dib);
        DeleteDC(screenMem);

        // إرجاع النتيجة
        CapturedScreenArea result;
        result.buffer = compressedBuffer;
        result.width = width;
        result.height = height;
        result.bitsPerPixel = 32;
        result.bytesPerPixel = 4;
        result.isCompressed = true;

        return result;
    }

} // namespace flutter_screen_capture