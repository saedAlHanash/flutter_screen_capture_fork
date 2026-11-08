#include "include/flutter_screen_capture/flutter_screen_capture_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <cstring>
#include <vector>
#include <gdk/gdk.h>

// Captures an area of the root window (X11). Returns a new RGBA pixbuf
// with 4 channels, or nullptr on failure. The caller owns the result.
//
// Note: on Wayland the root window is not readable, so this returns nullptr
// (or a black image) and the Dart side gets a CAPTURE_FAILED error.
static GdkPixbuf *CaptureScreenArea(int64_t x, int64_t y, int64_t width, int64_t height)
{
    if (width <= 0 || height <= 0)
        return nullptr;

    GdkWindow *window = gdk_get_default_root_window();
    if (window == nullptr)
        return nullptr;

    GdkPixbuf *screenshot = gdk_pixbuf_get_from_window(window, x, y, width, height);
    if (screenshot == nullptr)
        return nullptr;

    // gdk_pixbuf_add_alpha returns a new pixbuf; the original must be released.
    GdkPixbuf *screenshotWithAlpha = gdk_pixbuf_add_alpha(screenshot, FALSE, 0, 0, 0);
    g_object_unref(screenshot);
    return screenshotWithAlpha;
}

// Copies the pixbuf pixels into a tightly packed buffer (no row padding).
static FlValue *PixbufToTightBuffer(GdkPixbuf *pixbuf)
{
    const int width = gdk_pixbuf_get_width(pixbuf);
    const int height = gdk_pixbuf_get_height(pixbuf);
    const int channels = gdk_pixbuf_get_n_channels(pixbuf);
    const int rowstride = gdk_pixbuf_get_rowstride(pixbuf);
    const guint8 *pixels = gdk_pixbuf_read_pixels(pixbuf);
    const size_t tightRow = static_cast<size_t>(width) * channels;

    if (static_cast<size_t>(rowstride) == tightRow)
        return fl_value_new_uint8_list(pixels, tightRow * height);

    std::vector<uint8_t> tight(tightRow * height);
    for (int row = 0; row < height; row++)
        memcpy(tight.data() + row * tightRow, pixels + static_cast<size_t>(row) * rowstride, tightRow);
    return fl_value_new_uint8_list(tight.data(), tight.size());
}

static bool GetIntArg(FlValue *args, const char *key, int64_t *out)
{
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP)
        return false;
    FlValue *value = fl_value_lookup_string(args, key);
    if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT)
        return false;
    *out = fl_value_get_int(value);
    return true;
}

struct _FlutterScreenCapturePlugin
{
    GObject parent_instance;
};

#define FLUTTER_SCREEN_CAPTURE_PLUGIN(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_screen_capture_plugin_get_type(), FlutterScreenCapturePlugin))

G_DEFINE_TYPE(FlutterScreenCapturePlugin, flutter_screen_capture_plugin, g_object_get_type())

static void flutter_screen_capture_plugin_dispose(GObject *object)
{
    G_OBJECT_CLASS(flutter_screen_capture_plugin_parent_class)->dispose(object);
}

static void flutter_screen_capture_plugin_class_init(FlutterScreenCapturePluginClass *klass)
{
    G_OBJECT_CLASS(klass)->dispose = flutter_screen_capture_plugin_dispose;
}

static void flutter_screen_capture_plugin_init(FlutterScreenCapturePlugin *self) {}

// Called when a method call is received from Flutter.
static void flutter_screen_capture_plugin_handle_method_call(
    FlutterScreenCapturePlugin *self,
    FlMethodCall *method_call)
{
    const gchar *method = fl_method_call_get_name(method_call);
    FlValue *args = fl_method_call_get_args(method_call);

    g_autoptr(FlMethodResponse) response = nullptr;
    if (strcmp(method, "captureScreenArea") == 0)
    {
        int64_t x, y, width, height;
        if (!GetIntArg(args, "x", &x) || !GetIntArg(args, "y", &y) ||
            !GetIntArg(args, "width", &width) || !GetIntArg(args, "height", &height))
        {
            response = FL_METHOD_RESPONSE(fl_method_error_response_new(
                "INVALID_ARGUMENTS", "Invalid arguments", nullptr));
        }
        else if (GdkPixbuf *capturedScreenArea = CaptureScreenArea(x, y, width, height))
        {
            const int channels = gdk_pixbuf_get_n_channels(capturedScreenArea);
            FlValue *dict = fl_value_new_map();
            fl_value_set_string_take(dict, "buffer", PixbufToTightBuffer(capturedScreenArea));
            fl_value_set_string_take(
                dict, "width", fl_value_new_int(gdk_pixbuf_get_width(capturedScreenArea)));
            fl_value_set_string_take(
                dict, "height", fl_value_new_int(gdk_pixbuf_get_height(capturedScreenArea)));
            fl_value_set_string_take(
                dict, "bitsPerPixel",
                fl_value_new_int(gdk_pixbuf_get_bits_per_sample(capturedScreenArea) * channels));
            fl_value_set_string_take(dict, "bytesPerPixel", fl_value_new_int(channels));

            g_object_unref(capturedScreenArea);

            response = FL_METHOD_RESPONSE(fl_method_success_response_new(dict));
            fl_value_unref(dict);
        }
        else
        {
            response = FL_METHOD_RESPONSE(fl_method_error_response_new(
                "CAPTURE_FAILED", "Unable to capture the screen area", nullptr));
        }
    }
    else
    {
        response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    }
    fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(
    FlMethodChannel *channel,
    FlMethodCall *method_call,
    gpointer user_data)
{
    FlutterScreenCapturePlugin *plugin = FLUTTER_SCREEN_CAPTURE_PLUGIN(user_data);
    flutter_screen_capture_plugin_handle_method_call(plugin, method_call);
}

void flutter_screen_capture_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
    FlutterScreenCapturePlugin *plugin = FLUTTER_SCREEN_CAPTURE_PLUGIN(
        g_object_new(
            flutter_screen_capture_plugin_get_type(),
            nullptr));

    g_autoptr(FlStandardMethodCodec)
        codec = fl_standard_method_codec_new();
    g_autoptr(FlMethodChannel)
        channel = fl_method_channel_new(
            fl_plugin_registrar_get_messenger(registrar),
            "flutter_screen_capture",
            FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(
        channel,
        method_call_cb,
        g_object_ref(plugin),
        g_object_unref);

    g_object_unref(plugin);
}
