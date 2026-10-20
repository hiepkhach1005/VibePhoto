import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 192 * 1024 * 1024
    }

    func image(for url: URL, size: CGSize, scale: CGFloat) async -> NSImage {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let key = "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)|\(Int(size.width))x\(Int(size.height))@\(scale)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: scale, representationTypes: .thumbnail
        )
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.nsImage
            let cost = max(1, Int(size.width * size.height * scale * scale * 4))
            cache.setObject(image, forKey: key, cost: cost)
            return image
        } catch {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    func removeAll() { cache.removeAllObjects() }
}
