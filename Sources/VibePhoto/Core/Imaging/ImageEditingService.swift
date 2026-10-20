@preconcurrency import CoreImage
@preconcurrency import ImageIO
import Foundation
import UniformTypeIdentifiers

enum ImageEditingError: LocalizedError {
    case unreadable
    case unsupportedOutput
    case renderFailed
    case writeFailed
    case changedExternally

    var errorDescription: String? {
        switch self {
        case .unreadable: "The image could not be read."
        case .unsupportedOutput: "This image format cannot be saved safely."
        case .renderFailed: "The edited image could not be rendered."
        case .writeFailed: "The edited image could not be written."
        case .changedExternally: "The file changed in another application. Reload it before editing."
        }
    }
}

enum RotationDirection { case left, right }

struct ImageEditBackup {
    let originalURL: URL
    let backupURL: URL
}

enum ImageEditingService {
    static func rotate(_ url: URL, direction: RotationDirection, expectedModificationDate: Date?) throws {
        try verifyUnchanged(url, expectedModificationDate: expectedModificationDate)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source),
              let input = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            throw ImageEditingError.unreadable
        }

        let orientation: CGImagePropertyOrientation = direction == .left ? .left : .right
        let output = input.oriented(orientation)
        try write(output, to: url, type: type, source: source)
    }

    static func resize(
        _ sourceURL: URL, width: Int, height: Int, destinationURL: URL,
        expectedModificationDate: Date?
    ) throws {
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            try verifyUnchanged(sourceURL, expectedModificationDate: expectedModificationDate)
        }
        guard width > 0, height > 0,
              let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let type = CGImageSourceGetType(source),
              let input = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true]) else {
            throw ImageEditingError.unreadable
        }
        let scaleX = CGFloat(width) / input.extent.width
        let scaleY = CGFloat(height) / input.extent.height
        let lanczos = CIFilter(name: "CILanczosScaleTransform")
        lanczos?.setValue(input, forKey: kCIInputImageKey)
        lanczos?.setValue(scaleY, forKey: kCIInputScaleKey)
        lanczos?.setValue(scaleX / scaleY, forKey: kCIInputAspectRatioKey)
        guard let output = lanczos?.outputImage else { throw ImageEditingError.renderFailed }
        try write(output, to: destinationURL, type: type, source: source)
    }

    static func makeBackup(of url: URL) throws -> ImageEditBackup {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("VibePhoto/EditBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let backup = base.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: backup)
        return .init(originalURL: url, backupURL: backup)
    }

    static func restore(_ backup: ImageEditBackup) throws {
        let data = try Data(contentsOf: backup.backupURL)
        try data.write(to: backup.originalURL, options: .atomic)
        try? FileManager.default.removeItem(at: backup.backupURL)
    }

    static func discard(_ backup: ImageEditBackup?) {
        guard let backup else { return }
        try? FileManager.default.removeItem(at: backup.backupURL)
    }

    static func uniqueResizeDestination(for source: URL) -> URL {
        let folder = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = folder.appendingPathComponent("\(base)-resized").appendingPathExtension(ext)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-resized-\(suffix)").appendingPathExtension(ext)
            suffix += 1
        }
        return candidate
    }

    private static func write(_ image: CIImage, to url: URL, type: CFString, source: CGImageSource) throws {
        let writableTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard writableTypes.contains(type as String) else { throw ImageEditingError.unsupportedOutput }
        let extent = image.extent.integral
        let normalized = image.transformed(by: .init(translationX: -extent.origin.x, y: -extent.origin.y))
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(normalized, from: CGRect(origin: .zero, size: extent.size)) else {
            throw ImageEditingError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            throw ImageEditingError.unsupportedOutput
        }
        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height
        if UTType(type as String)?.conforms(to: .jpeg) == true {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.95
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageEditingError.writeFailed }
        try (data as Data).write(to: url, options: .atomic)
    }

    private static func verifyUnchanged(_ url: URL, expectedModificationDate: Date?) throws {
        guard let expectedModificationDate else { return }
        let current = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if let current, abs(current.timeIntervalSince(expectedModificationDate)) > 0.001 {
            throw ImageEditingError.changedExternally
        }
    }
}
