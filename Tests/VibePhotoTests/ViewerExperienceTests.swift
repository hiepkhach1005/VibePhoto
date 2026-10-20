import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
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

    @Test @MainActor func navigationWrapsAroundBothEnds() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = try (1...3).map { number -> URL in
            let url = folder.appendingPathComponent("0\(number).png")
            try makeImage(at: url, metadata: false)
            return url
        }

        // An explicit browser collection needs no folder grant and steps only through its members.
        let model = ViewerViewModel(initialURL: urls[2], collection: [urls[0], urls[2]])
        model.load()
        #expect(model.items.map(\.url) == [urls[0], urls[2]])
        #expect(!model.needsFolderAccess)
        #expect(model.positionText == "2 / 2")

        model.next()
        #expect(model.currentURL == urls[0])
        model.previous()
        #expect(model.currentURL == urls[2])
        model.previous()
        model.previous()
        #expect(model.currentURL == urls[2])
        #expect(model.canGoPrevious && model.canGoNext)
    }

    @Test func parentFolderGrantCoversNestedFolders() {
        #expect(FolderAccessStore.path("/Users/me", covers: "/Users/me"))
        #expect(FolderAccessStore.path("/Users/me", covers: "/Users/me/Desktop/Image/jerry"))
        #expect(FolderAccessStore.path("/", covers: "/Volumes/Photos"))
        #expect(!FolderAccessStore.path("/Users/me", covers: "/Users/meow/Desktop"))
        #expect(!FolderAccessStore.path("/Users/me/Desktop", covers: "/Users/me"))
    }

    @Test @MainActor func gestureZoomIsNotSnappedBackByStaleSwiftUIState() {
        var zoom: CGFloat = 1
        var mode = ImageZoomMode.fit
        let coordinator = ZoomableImageView.Coordinator(
            zoom: Binding(get: { zoom }, set: { zoom = $0 }),
            mode: Binding(get: { mode }, set: { mode = $0 })
        )
        #expect(coordinator.isNewRequest(mode: .fit, zoom: 1))
        // SwiftUI re-renders with the same values while the view is mid-gesture: not a request.
        #expect(!coordinator.isNewRequest(mode: .fit, zoom: 1))
        // A toolbar zoom changes the bound values: a real request.
        #expect(coordinator.isNewRequest(mode: .custom, zoom: 1.25))
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
