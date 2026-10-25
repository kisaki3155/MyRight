import Foundation
import ImageIO
import CoreGraphics

@main
enum ImageConversionTests {
    static func image() -> CGImage {
        let context = CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.clear(CGRect(x: 0, y: 0, width: 120, height: 80))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 60, height: 80))
        return context.makeImage()!
    }

    static func write(_ image: CGImage, to url: URL, type: String = "public.png", frames: Int = 1, orientation: Int = 1) {
        let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, frames, nil)!
        for _ in 0..<frames { CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary) }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MyRight-images-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("中文 image.png")
        write(image(), to: source)
        let original = try Data(contentsOf: source)
        for format in ImageFormat.allCases {
            precondition(ImageConverter.supports(format), "Required encoder unavailable: \(format.title)")
            let output = try ImageConverter.convert(source, to: format)
            let decoded = CGImageSourceCreateWithURL(output as CFURL, nil)!
            precondition(CGImageSourceGetType(decoded)! as String == format.typeIdentifier)
            let pixels = CGImageSourceCreateImageAtIndex(decoded, 0, nil)!
            precondition(pixels.width == 120 && pixels.height == 80)
            precondition(tryData(source) == original)
            if format == .jpeg {
                let context = CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(pixels, in: CGRect(x: 0, y: 0, width: 120, height: 80))
                let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
                let offset = 40 * 480 + 100 * 4
                precondition(bytes[offset] > 245 && bytes[offset + 1] > 245 && bytes[offset + 2] > 245, "JPEG transparency must become white")
            }
            print("PASS: \(format.title) decodes at original dimensions, original untouched")
        }
        let collision = directory.appendingPathComponent("中文 image - 转换.png")
        let firstOutput = try Data(contentsOf: collision)
        let next = try ImageConverter.convert(source, to: .png)
        precondition(next.lastPathComponent == "中文 image - 转换 2.png")
        precondition(tryData(collision) == firstOutput)
        print("PASS: image conversion never overwrites an existing output")

        let rotated = directory.appendingPathComponent("rotated.tiff")
        write(image(), to: rotated, type: "public.tiff", orientation: 6)
        let upright = try ImageConverter.convert(rotated, to: .png)
        let uprightSource = CGImageSourceCreateWithURL(upright as CFURL, nil)!
        let uprightImage = CGImageSourceCreateImageAtIndex(uprightSource, 0, nil)!
        precondition(uprightImage.width == 80 && uprightImage.height == 120)
        print("PASS: EXIF orientation is applied without shrinking the image")

        let animated = directory.appendingPathComponent("animated.gif")
        write(image(), to: animated, type: "com.compuserve.gif", frames: 2)
        do {
            _ = try ImageConverter.convert(animated, to: .png)
            fatalError("Animated input was silently flattened")
        } catch ImageConversionError.multipleFrames { print("PASS: animated/multi-page input is rejected safely") }
        let invalid = directory.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: invalid)
        do {
            _ = try ImageConverter.convert(invalid, to: .jpeg)
            fatalError("Invalid image was accepted")
        } catch ImageConversionError.unreadable { print("PASS: invalid input creates no false image") }
    }

    static func tryData(_ url: URL) -> Data { try! Data(contentsOf: url) }
}
