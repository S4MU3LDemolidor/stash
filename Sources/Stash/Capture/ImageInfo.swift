import AppKit
import ImageIO

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
