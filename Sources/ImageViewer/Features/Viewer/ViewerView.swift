import AppKit
import SwiftUI

struct ViewerView: View {
    @ObservedObject var model: ViewerViewModel
    @AppStorage("confirmBeforeTrash") private var confirmBeforeTrash = true
    @State private var showTrashConfirmation = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            if let image = model.image {
                ZoomableImageView(
                    image: image,
                    zoom: $model.zoom,
                    mode: $model.zoomMode,
                    onPrevious: model.previous,
                    onNext: model.next
                )
            } else if model.isWorking {
                ProgressView()
            } else {
                ContentUnavailableView("Unable to display image", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(model.currentURL?.lastPathComponent ?? "Image Viewer")
        .toolbar { viewerToolbar }
        .inspector(isPresented: $model.showInspector) {
            MetadataInspector(sections: model.metadata)
                .inspectorColumnWidth(min: 260, ideal: 320, max: 440)
        }
        .sheet(isPresented: $model.showResize) {
            if let image = model.image {
                ResizeSheet(originalSize: image.pixelSize) { width, height, replace in
                    model.resize(width: width, height: height, replacingOriginal: replace)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Text(model.positionText)
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .padding(12)
        }
        .overlay(alignment: .top) {
            if model.needsFolderAccess {
                HStack(spacing: 10) {
                    Label(model.folderAccessMessage, systemImage: "folder.badge.questionmark")
                    Button("Allow Folder Access…") { model.requestFolderAccess() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 12)
            }
        }
        .onKeyPress(.leftArrow) { model.previous(); return .handled }
        .onKeyPress(.rightArrow) { model.next(); return .handled }
        .task(id: model.isSlideshow) {
            while model.isSlideshow && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard model.isSlideshow && !Task.isCancelled else { return }
                model.advanceSlideshow()
            }
        }
        .alert("Image Viewer", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK") {} } message: { Text(model.errorMessage ?? "Unknown error") }
        .confirmationDialog(
            "Move this image to Trash?", isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { model.moveToTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.currentURL?.lastPathComponent ?? "The selected image")
        }
    }

    @ToolbarContentBuilder private var viewerToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { model.previous() } label: { Label("Previous", systemImage: "chevron.left") }
                .disabled(!model.canGoPrevious)
            Button { model.next() } label: { Label("Next", systemImage: "chevron.right") }
                .disabled(!model.canGoNext)
        }
        ToolbarItemGroup {
            Button { model.rotate(.left) } label: { Label("Rotate Left", systemImage: "rotate.left") }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button { model.rotate(.right) } label: { Label("Rotate Right", systemImage: "rotate.right") }
                .keyboardShortcut("r", modifiers: .command)
            Button { model.undoLastEdit() } label: { Label("Undo Last Edit", systemImage: "arrow.uturn.backward") }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndoEdit)
            Button { model.showResize = true } label: { Label("Resize", systemImage: "arrow.up.left.and.arrow.down.right") }
            Button { model.toggleFavorite() } label: {
                Label(model.isFavorite ? "Remove from Favorites" : "Favorite", systemImage: model.isFavorite ? "heart.fill" : "heart")
            }
            .foregroundStyle(model.isFavorite ? .pink : .primary)
            Button {
                model.zoomMode = .custom
                model.zoom = max(0.05, model.zoom / 1.2)
            } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: .command)
            Text(model.zoom, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(minWidth: 45)
                .accessibilityLabel("Zoom level")
            Button {
                model.zoomMode = .custom
                model.zoom = min(32, model.zoom * 1.2)
            } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
                .keyboardShortcut("+", modifiers: .command)
            Menu {
                Button("Fit to Window") { model.zoomMode = .fit }
                    .keyboardShortcut("0", modifiers: .command)
                Button("Fill Window") { model.zoomMode = .fill }
                Button("Actual Size") { model.zoomMode = .actual }
                    .keyboardShortcut("1", modifiers: .command)
            } label: { Label("Zoom Mode", systemImage: "viewfinder") }
            Button { model.showInspector.toggle() } label: { Label("Information", systemImage: "info.circle") }
                .keyboardShortcut("i")
            if let url = model.currentURL {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            Button { model.copyCurrentFile() } label: { Label("Copy File", systemImage: "doc.on.doc") }
                .keyboardShortcut("c", modifiers: .command)
            Button {
                if let url = model.currentURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } label: { Label("Reveal in Finder", systemImage: "folder") }
            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: {
                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
                .keyboardShortcut("f", modifiers: [.command, .control])
            Button { model.isSlideshow.toggle() } label: {
                Label(model.isSlideshow ? "Stop Slideshow" : "Start Slideshow", systemImage: model.isSlideshow ? "pause.fill" : "play.fill")
            }
                .keyboardShortcut(.space, modifiers: [])
            Button(role: .destructive) {
                if confirmBeforeTrash { showTrashConfirmation = true } else { model.moveToTrash() }
            } label: { Label("Move to Trash", systemImage: "trash") }
                .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}

private extension NSImage {
    var pixelSize: CGSize {
        guard let representation = representations.first else { return size }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }
}
