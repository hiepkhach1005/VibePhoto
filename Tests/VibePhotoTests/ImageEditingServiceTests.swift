import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VibePhoto

struct ImageEditingServiceTests {
    @Test func rotateResizeAndRestoreBackup() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let original = folder.appendingPathComponent("fixture.png")
        try makePNG(at: original, width: 4, height: 2)
        let originalDate = try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let backup = try ImageEditingService.makeBackup(of: original)

        try ImageEditingService.rotate(original, direction: .right, expectedModificationDate: originalDate)
        #expect(pixelSize(of: original) == CGSize(width: 2, height: 4))

        try ImageEditingService.restore(backup)
        #expect(pixelSize(of: original) == CGSize(width: 4, height: 2))

        let resized = ImageEditingService.uniqueResizeDestination(for: original)
        let restoredDate = try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try ImageEditingService.resize(
            original, width: 8, height: 6, destinationURL: resized,
            expectedModificationDate: restoredDate
        )
        #expect(pixelSize(of: resized) == CGSize(width: 8, height: 6))
    }

    @Test func uniqueDestinationDoesNotOverwriteExistingCopies() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("photo.jpg")
        let first = folder.appendingPathComponent("photo-resized.jpg")
        try Data().write(to: original)
        try Data().write(to: first)
        #expect(ImageEditingService.uniqueResizeDestination(for: original).lastPathComponent == "photo-resized-2.jpg")
    }

    private func makePNG(at url: URL, width: Int, height: Int) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { throw TestFixtureError.writeFailed }
    }

    private func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }
        return CGSize(width: width.intValue, height: height.intValue)
    }

    private enum TestFixtureError: Error { case writeFailed }
}
