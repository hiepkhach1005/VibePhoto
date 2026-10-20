import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VibePhoto

struct ViewerExperienceTests {
    @Test @MainActor func fitZoomIsReportedAndImageStaysCentered() {
        let view = ImageScrollView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let image = NSImage(size: CGSize(width: 1600, height: 1200))
        var reportedZoom: CGFloat = 0
        view.onZoom = { reportedZoom = $0 }

        view.setImage(image)
        view.layoutSubtreeIfNeeded()
        view.apply(mode: .fit, customZoom: 1)

        #expect(view.zoomFactor < 1)
        #expect(abs(reportedZoom - view.zoomFactor) < 0.001)
        #expect(abs(view.imageView.imageDrawingRect.midX - view.imageView.bounds.midX) < 0.001)
        #expect(abs(view.imageView.imageDrawingRect.midY - view.imageView.bounds.midY) < 0.001)

        view.apply(mode: .custom, customZoom: 2)
        #expect(view.canPan)
        #expect(abs(view.contentView.bounds.midX - view.imageView.imageDrawingRect.midX) < 1)
        #expect(abs(view.contentView.bounds.midY - view.imageView.imageDrawingRect.midY) < 1)
    }

    @Test @MainActor func directFileWithSiblingsRequestsFolderAccess() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("01.png")
        let second = folder.appendingPathComponent("02.png")
        try makeImage(at: first, metadata: false)
        try makeImage(at: second, metadata: false)

        let model = ViewerViewModel(initialURL: first)
        model.load()

        #expect(model.items.count == 2)
        #expect(model.needsFolderAccess)
        #expect(model.canGoNext)
    }

    @Test func metadataStartsWithReadableSummaryAndKeepsTechnicalDetails() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("metadata-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeImage(at: url, metadata: true)

        let sections = ImageMetadataService.read(from: url)
        let imageRows = sections.first(where: { $0.title == "Image" })?.rows ?? []
        let cameraRows = sections.first(where: { $0.title == "Camera" })?.rows ?? []

        #expect(imageRows.contains { $0.label == "Dimensions" && $0.value == "8 × 6 pixels" })
        #expect(imageRows.contains { $0.label == "Aspect ratio" && $0.value == "4:3" })
        #expect(cameraRows.contains { $0.label == "Camera maker" && $0.value == "Example Camera Co." })
        #expect(sections.contains { $0.isTechnical && $0.title == "EXIF details" })
    }

    private func makeImage(at url: URL, metadata: Bool) throws {
        let context = CGContext(
            data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FixtureError.cannotCreateDestination
        }
        let properties: CFDictionary? = metadata ? [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Example Camera Co."],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifExposureTime: 0.02]
        ] as CFDictionary : nil
        CGImageDestinationAddImage(destination, context.makeImage()!, properties)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.cannotWriteImage }
    }

    private enum FixtureError: Error {
        case cannotCreateDestination
        case cannotWriteImage
    }
}
