import AppKit
import SwiftUI

enum ImageZoomMode: String, CaseIterable {
    case fit
    case fill
    case actual
    case custom
}

struct ZoomableImageView: NSViewRepresentable {
    let image: NSImage
    @Binding var zoom: CGFloat
    @Binding var mode: ImageZoomMode
    let onPrevious: () -> Void
    let onNext: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom, mode: $mode) }

    func makeNSView(context: Context) -> ImageScrollView {
        let view = ImageScrollView()
        view.onZoom = { context.coordinator.reportZoom($0) }
        view.onModeChange = { context.coordinator.reportMode($0) }
        view.imageView.onPrevious = onPrevious
        view.imageView.onNext = onNext
        view.setImage(image)
        view.apply(mode: mode, customZoom: zoom)
        return view
    }

    func updateNSView(_ view: ImageScrollView, context: Context) {
        view.imageView.onPrevious = onPrevious
        view.imageView.onNext = onNext
        if view.imageView.image !== image { view.setImage(image) }
        view.apply(mode: mode, customZoom: zoom)
    }

    @MainActor final class Coordinator {
        var zoom: Binding<CGFloat>
        var mode: Binding<ImageZoomMode>
        init(zoom: Binding<CGFloat>, mode: Binding<ImageZoomMode>) {
            self.zoom = zoom
            self.mode = mode
        }

        func reportZoom(_ value: CGFloat) {
            guard abs(zoom.wrappedValue - value) > 0.0001 else { return }
            RunLoop.main.perform { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, abs(self.zoom.wrappedValue - value) > 0.0001 else { return }
                    self.zoom.wrappedValue = value
                }
            }
        }

        func reportMode(_ value: ImageZoomMode) {
            guard mode.wrappedValue != value else { return }
            RunLoop.main.perform { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.mode.wrappedValue != value else { return }
                    self.mode.wrappedValue = value
                }
            }
        }
    }
}

final class ImageScrollView: NSScrollView {
    let imageView = ImageCanvasView()
    var onZoom: ((CGFloat) -> Void)?
    var onModeChange: ((ImageZoomMode) -> Void)?
    private(set) var zoomFactor: CGFloat = 1
    private var mode: ImageZoomMode = .fit
    private var panStartLocation: CGPoint?
    private var panStartOrigin: CGPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        hasHorizontalScroller = true
        hasVerticalScroller = true
        autohidesScrollers = true
        allowsMagnification = false
        imageView.onDoubleClick = { [weak self] in self?.toggleFitActual() }
        imageView.onPanBegan = { [weak self] in self?.beginPan(with: $0) }
        imageView.onPanChanged = { [weak self] in self?.continuePan(with: $0) }
        imageView.onPanEnded = { [weak self] in self?.endPan() }
        documentView = imageView
    }

    required init?(coder: NSCoder) { nil }

    func setImage(_ image: NSImage) {
        imageView.image = image
        updateDocumentSize()
        apply(mode: mode, customZoom: zoomFactor)
        centerImage()
    }

    func apply(mode: ImageZoomMode, customZoom: CGFloat) {
        let modeChanged = self.mode != mode
        self.mode = mode
        switch mode {
        case .fit:
            setZoom(scaleToFit(), center: modeChanged)
        case .fill:
            setZoom(scaleToFill(), center: modeChanged)
        case .actual:
            setZoom(1, center: modeChanged)
        case .custom:
            if abs(customZoom - zoomFactor) > 0.0001 {
                setZoom(customZoom, center: true)
            } else {
                onZoom?(zoomFactor)
            }
        }
    }

    override func layout() {
        super.layout()
        if mode != .custom { apply(mode: mode, customZoom: zoomFactor) }
    }

    private func setZoom(
        _ value: CGFloat,
        anchorDocumentPoint: CGPoint? = nil,
        viewportOffset: CGPoint? = nil,
        center: Bool = false
    ) {
        let clamped = min(32, max(0.05, value))
        guard abs(clamped - zoomFactor) > 0.0001 else {
            onZoom?(zoomFactor)
            if center { centerImage() }
            return
        }

        let oldImageRect = imageView.imageDrawingRect
        let anchor = anchorDocumentPoint ?? CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        let offset = viewportOffset ?? CGPoint(x: contentView.bounds.width / 2, y: contentView.bounds.height / 2)
        let normalizedAnchor: CGPoint
        if oldImageRect.width > 0, oldImageRect.height > 0, oldImageRect.contains(anchor) {
            normalizedAnchor = CGPoint(
                x: (anchor.x - oldImageRect.minX) / oldImageRect.width,
                y: (anchor.y - oldImageRect.minY) / oldImageRect.height
            )
        } else {
            normalizedAnchor = CGPoint(x: 0.5, y: 0.5)
        }

        zoomFactor = clamped
        updateDocumentSize()
        if center {
            centerImage()
        } else {
            let newImageRect = imageView.imageDrawingRect
            let target = CGPoint(
                x: newImageRect.minX + normalizedAnchor.x * newImageRect.width,
                y: newImageRect.minY + normalizedAnchor.y * newImageRect.height
            )
            scroll(to: CGPoint(x: target.x - offset.x, y: target.y - offset.y))
        }
        onZoom?(zoomFactor)
    }

    override func scrollWheel(with event: NSEvent) {
        let pointerInDocument = imageView.convert(event.locationInWindow, from: nil)
        let pointerInClip = contentView.convert(event.locationInWindow, from: nil)
        let viewportOffset = CGPoint(
            x: pointerInClip.x - contentView.bounds.minX,
            y: pointerInClip.y - contentView.bounds.minY
        )
        let factor = exp(event.scrollingDeltaY * 0.012)
        mode = .custom
        onModeChange?(.custom)
        setZoom(
            zoomFactor * factor,
            anchorDocumentPoint: pointerInDocument,
            viewportOffset: viewportOffset
        )
    }

    override func magnify(with event: NSEvent) {
        mode = .custom
        onModeChange?(.custom)
        setZoom(zoomFactor * (1 + event.magnification))
    }

    private func updateDocumentSize() {
        guard let image = imageView.image else { return }
        let displayedSize = CGSize(
            width: image.size.width * zoomFactor,
            height: image.size.height * zoomFactor
        )
        imageView.displayedImageSize = displayedSize
        let size = CGSize(
            width: max(contentSize.width, displayedSize.width),
            height: max(contentSize.height, displayedSize.height)
        )
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.needsDisplay = true
        imageView.updateCursor()
    }

    private func scaleToFit() -> CGFloat {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return 1 }
        return min(max(1, contentSize.width - 16) / image.size.width, max(1, contentSize.height - 16) / image.size.height)
    }

    private func scaleToFill() -> CGFloat {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(contentSize.width / image.size.width, contentSize.height / image.size.height)
    }

    private func toggleFitActual() {
        let next: ImageZoomMode = mode == .actual ? .fit : .actual
        apply(mode: next, customZoom: zoomFactor)
        onModeChange?(next)
        onZoom?(zoomFactor)
    }

    private func centerImage() {
        let imageRect = imageView.imageDrawingRect
        scroll(to: CGPoint(
            x: imageRect.midX - contentView.bounds.width / 2,
            y: imageRect.midY - contentView.bounds.height / 2
        ))
    }

    private func scroll(to origin: CGPoint) {
        var proposedBounds = contentView.bounds
        proposedBounds.origin = origin
        let constrained = contentView.constrainBoundsRect(proposedBounds)
        contentView.scroll(to: constrained.origin)
        reflectScrolledClipView(contentView)
    }

    private func beginPan(with event: NSEvent) {
        guard canPan else { return }
        panStartLocation = event.locationInWindow
        panStartOrigin = contentView.bounds.origin
        NSCursor.closedHand.push()
    }

    private func continuePan(with event: NSEvent) {
        guard let startLocation = panStartLocation, let startOrigin = panStartOrigin else { return }
        let delta = CGPoint(
            x: event.locationInWindow.x - startLocation.x,
            y: event.locationInWindow.y - startLocation.y
        )
        scroll(to: CGPoint(x: startOrigin.x - delta.x, y: startOrigin.y + delta.y))
    }

    private func endPan() {
        guard panStartLocation != nil else { return }
        panStartLocation = nil
        panStartOrigin = nil
        NSCursor.pop()
    }

    var canPan: Bool {
        imageView.frame.width > contentSize.width + 1 || imageView.frame.height > contentSize.height + 1
    }
}

final class ImageCanvasView: NSImageView {
    var onDoubleClick: (() -> Void)?
    var onPanBegan: ((NSEvent) -> Void)?
    var onPanChanged: ((NSEvent) -> Void)?
    var onPanEnded: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var displayedImageSize: CGSize = .zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    var imageDrawingRect: CGRect {
        CGRect(
            x: (bounds.width - displayedImageSize.width) / 2,
            y: (bounds.height - displayedImageSize.height) / 2,
            width: displayedImageSize.width,
            height: displayedImageSize.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, displayedImageSize.width > 0, displayedImageSize.height > 0 else { return }
        image.draw(
            in: imageDrawingRect,
            from: CGRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            onPanBegan?(event)
        }
    }

    override func mouseDragged(with event: NSEvent) { onPanChanged?(event) }
    override func mouseUp(with event: NSEvent) { onPanEnded?() }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: onPrevious?()
        case 124: onNext?()
        default: super.keyDown(with: event)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        RunLoop.main.perform { [weak self, weak window] in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                window.makeFirstResponder(self)
            }
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        updateCursor()
    }

    func updateCursor() {
        discardCursorRects()
        addCursorRect(bounds, cursor: enclosingScrollView?.documentVisibleRect.size == bounds.size ? .arrow : .openHand)
    }
}
