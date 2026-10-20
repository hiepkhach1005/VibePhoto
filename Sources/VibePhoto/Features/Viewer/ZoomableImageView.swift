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
        let coordinator = context.coordinator
        coordinator.view = view
        view.onZoom = { [weak coordinator] _ in coordinator?.scheduleSync() }
        view.onModeChange = { [weak coordinator] _ in coordinator?.scheduleSync() }
        view.imageView.onPrevious = onPrevious
        view.imageView.onNext = onNext
        view.setImage(image)
        _ = coordinator.isNewRequest(mode: mode, zoom: zoom)
        view.apply(mode: mode, customZoom: zoom)
        return view
    }

    func updateNSView(_ view: ImageScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.zoom = $zoom
        coordinator.mode = $mode
        view.imageView.onPrevious = onPrevious
        view.imageView.onNext = onNext
        if view.imageView.image !== image { view.setImage(image) }
        // Only forward values SwiftUI changed. Values the view reported itself may
        // still be in flight; re-applying them would snap the zoom back mid-gesture.
        if coordinator.isNewRequest(mode: mode, zoom: zoom) {
            view.apply(mode: mode, customZoom: zoom)
        }
    }

    @MainActor final class Coordinator {
        var zoom: Binding<CGFloat>
        var mode: Binding<ImageZoomMode>
        weak var view: ImageScrollView?
        private var syncedZoom: CGFloat?
        private var syncedMode: ImageZoomMode?
        private var syncScheduled = false

        init(zoom: Binding<CGFloat>, mode: Binding<ImageZoomMode>) {
            self.zoom = zoom
            self.mode = mode
        }

        func isNewRequest(mode: ImageZoomMode, zoom: CGFloat) -> Bool {
            defer {
                syncedMode = mode
                syncedZoom = zoom
            }
            guard let syncedZoom, let syncedMode else { return true }
            return mode != syncedMode || abs(zoom - syncedZoom) > 0.0001
        }

        /// Coalesces the many zoom changes of one gesture into a single SwiftUI update per run-loop pass.
        func scheduleSync() {
            guard !syncScheduled else { return }
            syncScheduled = true
            RunLoop.main.perform { [weak self] in
                MainActor.assumeIsolated { self?.flush() }
            }
        }

        private func flush() {
            syncScheduled = false
            guard let view else { return }
            syncedZoom = view.zoomFactor
            syncedMode = view.mode
            if mode.wrappedValue != view.mode { mode.wrappedValue = view.mode }
            if abs(zoom.wrappedValue - view.zoomFactor) > 0.0001 { zoom.wrappedValue = view.zoomFactor }
        }
    }
}

final class ImageScrollView: NSScrollView {
    let imageView = ImageCanvasView()
    var onZoom: ((CGFloat) -> Void)?
    var onModeChange: ((ImageZoomMode) -> Void)?
    private(set) var zoomFactor: CGFloat = 1
    private(set) var mode: ImageZoomMode = .fit
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
            // Toolbar and keyboard zoom keep the middle of the viewport in place.
            setZoom(customZoom)
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
        // Trackpads report many small pixel deltas; mouse wheels report a few whole lines.
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.01 : 0.08
        let factor = exp(event.scrollingDeltaY * sensitivity)
        setMode(.custom)
        setZoom(
            zoomFactor * factor,
            anchorDocumentPoint: pointerInDocument,
            viewportOffset: viewportOffset
        )
    }

    override func magnify(with event: NSEvent) {
        let pointerInDocument = imageView.convert(event.locationInWindow, from: nil)
        let pointerInClip = contentView.convert(event.locationInWindow, from: nil)
        setMode(.custom)
        setZoom(
            zoomFactor * (1 + event.magnification),
            anchorDocumentPoint: pointerInDocument,
            viewportOffset: CGPoint(
                x: pointerInClip.x - contentView.bounds.minX,
                y: pointerInClip.y - contentView.bounds.minY
            )
        )
    }

    private func setMode(_ newMode: ImageZoomMode) {
        guard mode != newMode else { return }
        mode = newMode
        onModeChange?(newMode)
    }

    private func updateDocumentSize() {
        guard let image = imageView.image else { return }
        let displayedSize = CGSize(
            width: image.size.width * zoomFactor,
            height: image.size.height * zoomFactor
        )
        let size = CGSize(
            width: max(contentSize.width, displayedSize.width),
            height: max(contentSize.height, displayedSize.height)
        )
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.displayedImageSize = displayedSize
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

final class ImageCanvasView: NSView {
    var onDoubleClick: (() -> Void)?
    var onPanBegan: ((NSEvent) -> Void)?
    var onPanChanged: ((NSEvent) -> Void)?
    var onPanEnded: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var image: NSImage? {
        didSet { imageLayerView.image = image }
    }
    var displayedImageSize: CGSize = .zero {
        didSet { imageLayerView.frame = imageDrawingRect }
    }

    // The bitmap lives in a layer so Core Animation scales it on the GPU while
    // zooming, instead of redrawing the full-resolution image for every event.
    private let imageLayerView = ImageLayerView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(imageLayerView)
    }

    required init?(coder: NSCoder) { nil }

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

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        imageLayerView.frame = imageDrawingRect
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

private final class ImageLayerView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer else { return }
        layer.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        layer.contentsGravity = .resize
        layer.minificationFilter = .trilinear
        layer.magnificationFilter = .linear
    }

    // Mouse handling belongs to the canvas underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
