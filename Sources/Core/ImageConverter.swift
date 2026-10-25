import Foundation
import ImageIO
import CoreGraphics

enum ImageConversionError: LocalizedError {
    case unreadable, multipleFrames, unavailableFormat, encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取这张图片，请确认文件完整且为系统支持的图片格式。"
        case .multipleFrames: return "这张图片包含动画或多个页面。为避免丢失内容，暂不转换多帧图片。"
        case .unavailableFormat: return "当前系统不支持写入所选图片格式。"
        case .encodingFailed: return "图片转换失败，原文件未被修改。"
        }
    }
}

enum ImageConverter {
    static func supports(_ format: ImageFormat) -> Bool {
        (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains(format.typeIdentifier)
    }

    static func convert(_ sourceURL: URL, to format: ImageFormat) throws -> URL {
        guard supports(format) else { throw ImageConversionError.unavailableFormat }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw ImageConversionError.unreadable }
        guard CGImageSourceGetCount(source) == 1 else { throw ImageConversionError.multipleFrames }
        // Render at the original resolution and apply EXIF orientation once.
        // This avoids rotated exports and does not silently downsize the image.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height)
        ]
        guard var image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageConversionError.unreadable
        }
        if format == .jpeg {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw ImageConversionError.encodingFailed
            }
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            context.draw(image, in: bounds)
            guard let flattened = context.makeImage() else { throw ImageConversionError.encodingFailed }
            image = flattened
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.typeIdentifier as CFString, 1, nil) else {
            throw ImageConversionError.encodingFailed
        }
        let outputProperties: [CFString: Any] = [
            kCGImagePropertyOrientation: 1,
            kCGImageDestinationLossyCompressionQuality: 0.92
        ]
        CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageConversionError.encodingFailed }

        let directory = sourceURL.deletingLastPathComponent()
        let stem = sourceURL.deletingPathExtension().lastPathComponent + " - 转换"
        for number in 0..<1000 {
            let name = number == 0 ? stem : "\(stem) \(number + 1)"
            let output = directory.appendingPathComponent(name).appendingPathExtension(format.fileExtension)
            do {
                try (data as Data).write(to: output, options: .withoutOverwriting)
                return output
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
                throw error
            }
        }
        throw ActionError.tooManyFiles
    }
}
