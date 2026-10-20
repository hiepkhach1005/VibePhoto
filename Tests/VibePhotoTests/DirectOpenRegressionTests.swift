import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VibePhoto

struct DirectOpenRegressionTests {
    @Test func commonExtensionsAreRecognizedWithoutReadingResourceMetadata() {
        let folder = URL(fileURLWithPath: "/a/folder", isDirectory: true)
        for name in ["photo.png", "photo.jpg", "photo.jpeg", "photo.heic", "photo.heif"] {
            #expect(ImageFileService.isSupported(folder.appendingPathComponent(name)))
        }
        #expect(!ImageFileService.isSupported(folder.appendingPathComponent("notes.txt")))
    }

    @Test func routeUsesOneDestinationForFilesAndFolders() {
        let file = URL(fileURLWithPath: "/tmp/photo.heic")
        let folder = URL(fileURLWithPath: "/tmp/Album", isDirectory: true)
        #expect(AppWindowRoute.destination(for: file) == .viewer(file))
        #expect(AppWindowRoute.destination(for: folder) == .browser(folder))
    }

    @Test func imageIODecodesPNGJPEGAndHEIC() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let formats: [(String, UTType)] = [("png", .png), ("jpg", .jpeg), ("heic", .heic)]
        for (extensionName, type) in formats {
            let url = folder.appendingPathComponent("fixture.\(extensionName)")
            try makeImage(at: url, type: type)
            #expect(ImageFileService.isSupported(url))
            let decoded = ImageLoadingService.loadImage(at: url)
            #expect(decoded != nil, "Expected Image I/O to decode \(extensionName)")
            // NSImage may cache a Retina representation, so validate its logical
            // dimensions instead of the backing representation's device pixels.
            #expect(decoded?.size.width == 6)
            #expect(decoded?.size.height == 4)
        }
    }

    private func makeImage(at url: URL, type: UTType) throws {
        let context = CGContext(
            data: nil, width: 6, height: 4, bitsPerComponent: 8, bytesPerRow: 24,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.15, green: 0.55, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 6, height: 4))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw FixtureError.encoderUnavailable(type.identifier)
        }
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.encodingFailed(type.identifier)
        }
    }

    private enum FixtureError: Error {
        case encoderUnavailable(String)
        case encodingFailed(String)
    }
}
