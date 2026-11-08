import Cocoa
import FlutterMacOS

private struct CapturedScreenArea {
    let buffer: Data
    let width: Int
    let height: Int
    let bitsPerPixel: Int
    let bytesPerPixel: Int
}

/// Draws `image` into a new bitmap of `width` x `height` pixels and returns
/// its bytes as tightly packed BGRA (8 bits per channel, no row padding).
///
/// Drawing into a context with a fixed layout removes three problems of the
/// raw CGImage buffer: row padding (`bytesPerRow` > `width * 4`), unknown
/// pixel formats, and Retina images that are 2x/3x larger than requested.
private func renderTightBGRA(_ image: CGImage, width: Int, height: Int) -> Data? {
    guard width > 0, height > 0 else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    // Keep the source colour space so picked colours are not converted.
    let colorSpace: CGColorSpace
    if let source = image.colorSpace, source.model == .rgb {
        colorSpace = source
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB()
    }
    // Little-endian + alpha first = B, G, R, A in memory.
    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
        | CGImageAlphaInfo.premultipliedFirst.rawValue

    var data = Data(count: bytesPerRow * height)
    let drawn = data.withUnsafeMutableBytes { raw -> Bool in
        guard let context = CGContext(
            data: raw.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return false
        }
        // Nearest-neighbour keeps single pixels exact for colour picking.
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return drawn ? data : nil
}

private func captureScreenArea(x: Int, y: Int, width: Int, height: Int) -> CapturedScreenArea? {
    guard width > 0, height > 0 else { return nil }
    let rect = CGRect(x: x, y: y, width: width, height: height)

    // NOTE: CGWindowListCreateImage is deprecated since macOS 14 and Apple
    // recommends ScreenCaptureKit. It still works on current releases but
    // requires the Screen Recording permission.
    guard let image = CGWindowListCreateImage(
        rect,
        .optionAll,
        kCGNullWindowID,
        .bestResolution
    ) else {
        return nil
    }

    // On Retina displays the image is 2x or 3x the requested size in points.
    // The OS may crop the image when the rect is partly off-screen, so use the
    // larger of the two axis ratios to estimate the backing scale factor.
    let ratio = max(
        Double(image.width) / Double(width),
        Double(image.height) / Double(height),
        1
    )
    let outWidth = max(1, Int((Double(image.width) / ratio).rounded()))
    let outHeight = max(1, Int((Double(image.height) / ratio).rounded()))

    guard let buffer = renderTightBGRA(image, width: outWidth, height: outHeight) else {
        return nil
    }

    return CapturedScreenArea(
        buffer: buffer,
        width: outWidth,
        height: outHeight,
        bitsPerPixel: 32,
        bytesPerPixel: 4
    )
}

private let invalidArgumentsError = FlutterError(
    code: "INVALID_ARGUMENTS",
    message: "Invalid arguments",
    details: nil
)

private struct CaptureAreaArgs {
    let x, y, width, height: Int

    init?(from call: FlutterMethodCall) {
        guard
            let args = call.arguments as? [String: Any],
            let x = args["x"] as? Int,
            let y = args["y"] as? Int,
            let width = args["width"] as? Int,
            let height = args["height"] as? Int,
            width > 0,
            height > 0
        else {
            return nil
        }

        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public class FlutterScreenCapturePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_screen_capture",
            binaryMessenger: registrar.messenger
        )
        let instance = FlutterScreenCapturePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "captureScreenArea":
            handleCaptureScreenArea(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleCaptureScreenArea(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = CaptureAreaArgs(from: call) else {
            result(invalidArgumentsError)
            return
        }

        if let capturedArea = captureScreenArea(
            x: args.x,
            y: args.y,
            width: args.width,
            height: args.height
        ) {
            result([
                "buffer": FlutterStandardTypedData(bytes: capturedArea.buffer),
                "width": capturedArea.width,
                "height": capturedArea.height,
                "bitsPerPixel": capturedArea.bitsPerPixel,
                "bytesPerPixel": capturedArea.bytesPerPixel,
            ])
        } else {
            result(nil)
        }
    }
}
