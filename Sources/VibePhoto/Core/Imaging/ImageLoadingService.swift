@preconcurrency import ImageIO
import AppKit
import Foundation

/// A decoded image plus the details the viewer shows with it, safe to hand from a background task.
struct LoadedImage: @unchecked Sendable {
    let image: NSImage
    let metadata: [MetadataSection]
    let modificationDate: Date?
}

enum ImageLoadingService {
    /// Decodes an image and its metadata; call off the main actor.
    static func loadForDisplay(at url: URL) -> LoadedImage? {
        guard let image = loadImage(at: url) else { return nil }
        let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return LoadedImage(image: image, metadata: ImageMetadataService.read(from: url), modificationDate: modificationDate)
    }

    static func loadImage(at url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        // Core Animation textures top out at 16K pixels per side.
        let maximumDimension = min(16_384, max(1, max(width, height)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
