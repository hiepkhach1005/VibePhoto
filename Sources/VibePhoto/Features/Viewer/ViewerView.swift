import AppKit
import SwiftUI

struct ViewerView: View {
    @ObservedObject var model: ViewerViewModel
    /// Returns to the browser grid when the viewer is shown inside a browser window.
    var onClose: (() -> Void)?
    /// Shows the Favorites collection in this window.
    var onShowFavorites: (() -> Void)?
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
            } else if model.isWorking || model.isLoadingImage {
                ProgressView()
            } else {
                ContentUnavailableView("Unable to display image", systemImage: "exclamationmark.triangle")
            }
        }
        .background { keyboardShortcuts }
        .navigationTitle(model.currentURL?.lastPathComponent ?? "VibePhoto")
        .toolbar { viewerToolbar }
        .inspector(isPresented: $model.showInspector) {
            MetadataInspector(sections: model.metadata) { model.showInspector = false }
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
            VStack(spacing: 8) {
                if let notice = model.favoriteNotice { favoriteToast(notice) }
                Text(model.positionText)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(12)
            .animation(.easeOut(duration: 0.2), value: model.favoriteNotice)
        }
        .overlay(alignment: .top) {
            if model.needsFolderAccess { folderAccessBanner }
        }
        .task(id: model.isSlideshow) {
            while model.isSlideshow && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard model.isSlideshow && !Task.isCancelled else { return }
                model.advanceSlideshow()
            }
        }
        .task(id: model.favoriteNotice) {
            guard model.favoriteNotice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            model.favoriteNotice = nil
        }
        .alert("VibePhoto", isPresented: Binding(
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

    private var folderAccessBanner: some View {
        HStack(spacing: 10) {
            Label(model.folderAccessMessage, systemImage: "folder.badge.questionmark")
            Button("Allow This Folder…") { model.requestFolderAccess() }
                .buttonStyle(.borderedProminent)
                .help("Grant access to the folder containing this image")
            Button("Allow Home Folder…") { model.requestHomeFolderAccess() }
                .help("Grant access once to your Home folder so VibePhoto never asks again for folders inside it")
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .padding(.top, 12)
    }

    private func favoriteToast(_ notice: ViewerViewModel.FavoriteNotice) -> some View {
        HStack(spacing: 10) {
            Label(
                notice.added ? "Added to Favorites" : "Removed from Favorites",
                systemImage: notice.added ? "heart.fill" : "heart.slash"
            )
            .foregroundStyle(notice.added ? .pink : .secondary)
            if let onShowFavorites {
                Button("Show Favorites") {
                    model.favoriteNotice = nil
                    onShowFavorites()
                }
                .buttonStyle(.link)
            }
        }
        .font(.callout)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func zoomOut() {
        model.zoomMode = .custom
        model.zoom = max(0.05, model.zoom / 1.25)
    }

    private func zoomIn() {
        model.zoomMode = .custom
        model.zoom = min(32, model.zoom * 1.25)
    }

    private func requestTrash() {
        if confirmBeforeTrash { showTrashConfirmation = true } else { model.moveToTrash() }
    }

    private func handleEscape() {
        if model.showInspector {
            model.showInspector = false
        } else if model.isSlideshow {
            model.isSlideshow = false
        } else {
            onClose?()
        }
    }

    /// Shortcuts live on invisible buttons so they keep working for actions that sit
    /// in the More menu or in the toolbar overflow.
    private var keyboardShortcuts: some View {
        Group {
            Button("Previous") { model.previous() }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next") { model.next() }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("Close") { handleEscape() }.keyboardShortcut(.escape, modifiers: [])
            Button("Rotate Left") { model.rotate(.left) }.keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Rotate Right") { model.rotate(.right) }.keyboardShortcut("r", modifiers: .command)
            Button("Undo") { model.undoLastEdit() }.keyboardShortcut("z", modifiers: .command)
            Button("Zoom Out") { zoomOut() }.keyboardShortcut("-", modifiers: .command)
            Button("Zoom In") { zoomIn() }.keyboardShortcut("+", modifiers: .command)
            Button("Zoom In") { zoomIn() }.keyboardShortcut("=", modifiers: .command)
            Button("Fit") { model.zoomMode = .fit }.keyboardShortcut("0", modifiers: .command)
            Button("Actual Size") { model.zoomMode = .actual }.keyboardShortcut("1", modifiers: .command)
            Button("Information") { model.showInspector.toggle() }.keyboardShortcut("i", modifiers: .command)
            Button("Favorite") { model.toggleFavorite() }.keyboardShortcut("l", modifiers: .command)
            Button("Copy") { model.copyCurrentFile() }.keyboardShortcut("c", modifiers: .command)
            Button("Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }.keyboardShortcut("f", modifiers: [.command, .control])
            Button("Slideshow") { model.isSlideshow.toggle() }.keyboardShortcut(.space, modifiers: [])
            Button("Trash") { requestTrash() }.keyboardShortcut(.delete, modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ToolbarContentBuilder private var viewerToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            if let onClose {
                Button(action: onClose) { Label("Back to Browser", systemImage: "square.grid.2x2") }
                    .help("Back to Browser (Esc)")
            }
            Button { model.previous() } label: { Label("Previous", systemImage: "chevron.left") }
                .disabled(!model.canGoPrevious)
                .help("Previous Image (←) — wraps to the last image")
            Button { model.next() } label: { Label("Next", systemImage: "chevron.right") }
                .disabled(!model.canGoNext)
                .help("Next Image (→) — wraps to the first image")
        }
        ToolbarItemGroup {
            Button { zoomOut() } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                .help("Zoom Out (⌘−)")
            Text(model.zoom, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(minWidth: 45)
                .accessibilityLabel("Zoom level")
                .help("Current zoom level")
            Button { zoomIn() } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
                .help("Zoom In (⌘+)")
            Menu {
                Button("Fit to Window  ⌘0") { model.zoomMode = .fit }
                Button("Fill Window") { model.zoomMode = .fill }
                Button("Actual Size  ⌘1") { model.zoomMode = .actual }
            } label: { Label("Zoom Mode", systemImage: "viewfinder") }
                .help("Fit, Fill, or Actual Size")
            Button { model.toggleFavorite() } label: {
                Label(model.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: model.isFavorite ? "heart.fill" : "heart")
            }
            .foregroundStyle(model.isFavorite ? .pink : .primary)
            .help(model.isFavorite
                ? "Remove from Favorites (⌘L)"
                : "Add to Favorites (⌘L) — see them under Library ▸ Favorites in the browser")
            Button { model.isSlideshow.toggle() } label: {
                Label(model.isSlideshow ? "Stop Slideshow" : "Start Slideshow", systemImage: model.isSlideshow ? "pause.fill" : "play.fill")
            }
            .help(model.isSlideshow ? "Stop Slideshow (Space)" : "Start Slideshow (Space)")
            Button { model.showInspector.toggle() } label: { Label("Information", systemImage: "info.circle") }
                .help(model.showInspector ? "Hide Information (⌘I or Esc)" : "Show Information (⌘I)")
            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            Section("Edit") {
                Button("Rotate Left  ⇧⌘R", systemImage: "rotate.left") { model.rotate(.left) }
                Button("Rotate Right  ⌘R", systemImage: "rotate.right") { model.rotate(.right) }
                Button("Resize…", systemImage: "arrow.up.left.and.arrow.down.right") { model.showResize = true }
                Button("Undo Last Edit  ⌘Z", systemImage: "arrow.uturn.backward") { model.undoLastEdit() }
                    .disabled(!model.canUndoEdit)
            }
            Section("File") {
                if let url = model.currentURL {
                    ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
                }
                Button("Copy File  ⌘C", systemImage: "doc.on.doc") { model.copyCurrentFile() }
                Button("Reveal in Finder", systemImage: "folder") {
                    if let url = model.currentURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                if let onShowFavorites {
                    Button("Show Favorites", systemImage: "heart.text.square", action: onShowFavorites)
                }
            }
            Section {
                Button("Toggle Full Screen  ⌃⌘F", systemImage: "arrow.up.left.and.arrow.down.right.rectangle") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                Button("Move to Trash  ⌘⌫", systemImage: "trash", role: .destructive) { requestTrash() }
            }
        } label: { Label("More", systemImage: "ellipsis.circle") }
            .help("More: rotate, resize, share, copy, reveal in Finder, full screen, trash")
    }
}

private extension NSImage {
    var pixelSize: CGSize {
        guard let representation = representations.first else { return size }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }
}
