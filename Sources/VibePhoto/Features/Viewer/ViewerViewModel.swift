import AppKit
import Foundation

@MainActor
final class ViewerViewModel: ObservableObject {
    @Published private(set) var items: [ImageItem] = []
    @Published private(set) var index = 0
    @Published private(set) var image: NSImage?
    @Published private(set) var metadata: [MetadataSection] = []
    @Published var zoom: CGFloat = 1
    @Published var zoomMode: ImageZoomMode = .fit
    @Published var showInspector = false
    @Published var showResize = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var needsFolderAccess = false
    @Published var isSlideshow = false

    let favorites = FavoritesStore.shared
    private var initialURL: URL
    private var fileAccess: SecurityScopedAccess?
    private var folderAccess: SecurityScopedAccess?
    private var lastBackup: ImageEditBackup?
    private var lastKnownModificationDate: Date?

    init(initialURL: URL) {
        self.initialURL = initialURL
    }

    var currentURL: URL? { items.indices.contains(index) ? items[index].url : nil }
    var positionText: String { items.isEmpty ? "0 / 0" : "\(index + 1) / \(items.count)" }
    var canGoPrevious: Bool { index > 0 }
    var canGoNext: Bool { index + 1 < items.count }
    var folderAccessMessage: String {
        let folder = initialURL.deletingLastPathComponent().lastPathComponent
        return "Allow access to \(folder) to browse all \(items.count) images."
    }
    var isFavorite: Bool { currentURL.map(favorites.contains) ?? false }
    var canUndoEdit: Bool {
        guard let backup = lastBackup, let currentURL else { return false }
        return backup.originalURL.standardizedFileURL == currentURL.standardizedFileURL
    }

    func load() {
        if fileAccess == nil { fileAccess = SecurityScopedAccess(url: initialURL) }
        if folderAccess == nil {
            let parentPath = initialURL.deletingLastPathComponent().standardizedFileURL.path
            if let bookmark = FolderAccessStore.shared.folders.first(where: { $0.originalPath == parentPath }),
               let (_, access) = FolderAccessStore.shared.resolve(bookmark) {
                folderAccess = access
            }
        }
        do {
            let siblings = try ImageFileService.siblingImages(of: initialURL)
            if let targetIndex = siblings.firstIndex(where: {
                $0.url.standardizedFileURL == initialURL.standardizedFileURL
            }) {
                items = siblings
                index = targetIndex
                // A file opened by Finder carries permission for that file, not
                // reliably for its siblings. Ask once for the containing folder
                // before Previous/Next tries to decode another image.
                needsFolderAccess = siblings.count > 1 && folderAccess == nil
            } else if let item = ImageFileService.imageItem(for: initialURL) {
                items = [item]
                index = 0
                needsFolderAccess = true
            } else {
                throw ImageFileServiceError.cannotEnumerate(initialURL.deletingLastPathComponent())
            }
            loadCurrent()
        } catch {
            needsFolderAccess = true
            if let item = ImageFileService.imageItem(for: initialURL) {
                items = [item]
                index = 0
                loadCurrent()
            } else {
                errorMessage = "Unable to open this image: \(error.localizedDescription)"
            }
        }
    }

    func previous() { navigate(to: index - 1) }
    func next() { navigate(to: index + 1) }

    func advanceSlideshow() {
        guard !items.isEmpty else { return }
        if canGoNext { index += 1 } else { index = 0 }
        loadCurrent()
    }

    func copyCurrentFile() {
        guard let url = currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
    }

    @discardableResult
    func requestFolderAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = initialURL.deletingLastPathComponent()
        panel.prompt = "Grant Access"
        panel.message = "Choose the folder containing this image so VibePhoto can navigate neighboring images."
        guard panel.runModal() == .OK, let folder = panel.url else { return false }
        let expectedFolder = initialURL.deletingLastPathComponent().standardizedFileURL
        guard folder.standardizedFileURL == expectedFolder else {
            errorMessage = "Please choose the folder containing this image: \(expectedFolder.lastPathComponent)."
            return false
        }
        folderAccess = FolderAccessStore.shared.remember(folder)
        needsFolderAccess = false
        load()
        return true
    }

    func toggleFavorite() {
        guard let url = currentURL else { return }
        favorites.toggle(url)
        objectWillChange.send()
    }

    func rotate(_ direction: RotationDirection) {
        guard let url = currentURL else { return }
        let expectedDate = lastKnownModificationDate
        isWorking = true
        Task {
            var newBackup: ImageEditBackup?
            do {
                newBackup = try await Task.detached {
                    let backup = try ImageEditingService.makeBackup(of: url)
                    do {
                        try ImageEditingService.rotate(url, direction: direction, expectedModificationDate: expectedDate)
                        return backup
                    } catch {
                        ImageEditingService.discard(backup)
                        throw error
                    }
                }.value
                ImageEditingService.discard(lastBackup)
                lastBackup = newBackup
                ThumbnailCache.shared.removeAll()
                reloadCurrentImage()
            } catch {
                errorMessage = "Rotation failed: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    func resize(width: Int, height: Int, replacingOriginal: Bool) {
        guard let source = currentURL else { return }
        let destination: URL
        if replacingOriginal {
            destination = source
        } else {
            destination = ImageEditingService.uniqueResizeDestination(for: source)
        }
        let expectedDate = lastKnownModificationDate
        isWorking = true
        Task {
            var newBackup: ImageEditBackup?
            do {
                newBackup = try await Task.detached {
                    let backup = replacingOriginal ? try ImageEditingService.makeBackup(of: source) : nil
                    do {
                        try ImageEditingService.resize(
                            source, width: width, height: height, destinationURL: destination,
                            expectedModificationDate: expectedDate
                        )
                        return backup
                    } catch {
                        ImageEditingService.discard(backup)
                        throw error
                    }
                }.value
                if let newBackup {
                    ImageEditingService.discard(lastBackup)
                    lastBackup = newBackup
                }
                ThumbnailCache.shared.removeAll()
                showResize = false
                if replacingOriginal { reloadCurrentImage() } else { initialURL = destination; load() }
            } catch {
                errorMessage = "Resize failed: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    func undoLastEdit() {
        guard canUndoEdit, let backup = lastBackup else { return }
        do {
            try ImageEditingService.restore(backup)
            lastBackup = nil
            ThumbnailCache.shared.removeAll()
            reloadCurrentImage()
        } catch {
            errorMessage = "Undo failed: \(error.localizedDescription)"
        }
    }

    func moveToTrash() {
        guard let url = currentURL else { return }
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            if favorites.contains(url) { favorites.toggle(url) }
            items.remove(at: index)
            if index >= items.count { index = max(0, items.count - 1) }
            loadCurrent()
        } catch {
            errorMessage = "Could not move the image to Trash: \(error.localizedDescription)"
        }
    }

    private func loadCurrent() {
        guard let url = currentURL else { image = nil; metadata = []; return }
        initialURL = url
        zoom = 1
        zoomMode = .fit
        reloadCurrentImage()
    }

    private func navigate(to requestedIndex: Int) {
        guard items.indices.contains(requestedIndex) else { return }
        let requestedURL = items[requestedIndex].url.standardizedFileURL
        if needsFolderAccess, !requestFolderAccess() { return }
        guard let resolvedIndex = items.firstIndex(where: {
            $0.url.standardizedFileURL == requestedURL
        }) else { return }
        index = resolvedIndex
        loadCurrent()
    }

    private func reloadCurrentImage() {
        guard let url = currentURL else { return }
        image = ImageLoadingService.loadImage(at: url)
        metadata = ImageMetadataService.read(from: url)
        lastKnownModificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if image == nil { errorMessage = "The image is unsupported or damaged." }
    }
}
