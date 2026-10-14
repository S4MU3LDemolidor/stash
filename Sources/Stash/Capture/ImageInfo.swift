import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Reads image size and makes small previews without decoding the full image.
enum ImageInfo {
    /// Pixel size, with width and height swapped for rotated (EXIF-oriented) photos.
    static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? (height, width) : (width, height)
    }

    static func pixelSize(data: Data) -> (width: Int, height: Int)? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap(pixelSize(of:))
    }

    static func pixelSize(fileURL: URL) -> (width: Int, height: Int)? {
        CGImageSourceCreateWithURL(fileURL as CFURL, nil).flatMap(pixelSize(of:))
    }

    /// A preview at most `maxPixels` on its longest side.
    static func thumbnail(of source: CGImageSource, maxPixels: Int = 240) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    static func thumbnail(data: Data) -> NSImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { thumbnail(of: $0) }
    }

    static func thumbnail(fileURL: URL, maxPixels: Int = 240) -> NSImage? {
        CGImageSourceCreateWithURL(fileURL as CFURL, nil).flatMap { thumbnail(of: $0, maxPixels: maxPixels) }
    }
}

// MARK: - Re-encoding (thumbnails and icons saved by enrichment)

extension ImageInfo {
    /// JPEG at most `maxPixels` on its longest side (web thumbnails can be large).
    static func jpegData(from data: Data, maxPixels: Int, quality: Double = 0.82) -> Data? {
        reencode(data, maxPixels: maxPixels, as: .jpeg, options: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    /// PNG at most `maxPixels` on its longest side (site icons, which may arrive as .ico).
    static func pngData(from data: Data, maxPixels: Int) -> Data? {
        reencode(data, maxPixels: maxPixels, as: .png, options: [:])
    }

    private static func reencode(_ data: Data, maxPixels: Int, as type: UTType, options: [CFString: Any]) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        // Icons often hold several sizes: take the largest.
        let index = (0..<CGImageSourceGetCount(source)).max { a, b in
            (pixelArea(source, a)) < (pixelArea(source, b))
        } ?? 0
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, thumbnailOptions as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static func pixelArea(_ source: CGImageSource, _ index: Int) -> Int {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        return (properties?[kCGImagePropertyPixelWidth] as? Int ?? 0) * (properties?[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }
}
