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
    @Published private(set) var isLoadingImage = false
    @Published var favoriteNotice: FavoriteNotice?
    @Published var errorMessage: String?
    @Published var needsFolderAccess = false
    @Published var isSlideshow = false

    let favorites = FavoritesStore.shared
    private var initialURL: URL
    /// An explicit set chosen in the browser; nil means "the images next to `initialURL`".
    private var collection: [URL]?
    private var loadTask: Task<Void, Never>?
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private var decodedImages: [URL: LoadedImage] = [:]
    private var fileAccess: SecurityScopedAccess?
    private var folderAccess: SecurityScopedAccess?
    private var lastBackup: ImageEditBackup?
    private var lastKnownModificationDate: Date?

    init(initialURL: URL, collection: [URL]? = nil) {
        self.initialURL = initialURL
        self.collection = collection
    }

    struct FavoriteNotice: Equatable {
        let id = UUID()
        let added: Bool
    }

    var currentURL: URL? { items.indices.contains(index) ? items[index].url : nil }
    var positionText: String { items.isEmpty ? "0 / 0" : "\(index + 1) / \(items.count)" }
    // Navigation wraps around, so both directions work whenever there is another image.
    var canGoPrevious: Bool { items.count > 1 }
    var canGoNext: Bool { items.count > 1 }
    var folderAccessMessage: String {
        let folder = initialURL.deletingLastPathComponent().lastPathComponent
        return "Allow access to “\(folder)” to browse the other images in it."
    }
    var isFavorite: Bool { currentURL.map(favorites.contains) ?? false }
    var canUndoEdit: Bool {
        guard let backup = lastBackup, let currentURL else { return false }
        return backup.originalURL.standardizedFileURL == currentURL.standardizedFileURL
    }

    func load() {
        if let collection {
            items = collection.compactMap(ImageFileService.imageItem)
            index = items.firstIndex { $0.url.standardizedFileURL == initialURL.standardizedFileURL } ?? 0
            needsFolderAccess = false
            loadCurrent()
            return
        }
        if fileAccess == nil { fileAccess = SecurityScopedAccess(url: initialURL) }
        if folderAccess == nil {
            folderAccess = FolderAccessStore.shared.accessCovering(initialURL.deletingLastPathComponent())
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

    func previous() { navigate(to: wrappedIndex(index - 1)) }
    func next() { navigate(to: wrappedIndex(index + 1)) }

    func advanceSlideshow() {
        guard !items.isEmpty else { return }
        index = wrappedIndex(index + 1)
        loadCurrent()
    }

    /// Shows another image in this same window instead of opening a new one.
    func open(_ url: URL) {
        let target = url.standardizedFileURL
        if let existing = items.firstIndex(where: { $0.url.standardizedFileURL == target }) {
            index = existing
            loadCurrent()
            return
        }
        initialURL = url
        collection = nil
        fileAccess = nil
        let folder = target.deletingLastPathComponent().path
        if let access = folderAccess, !FolderAccessStore.path(access.url.standardizedFileURL.path, covers: folder) {
            folderAccess = nil
        }
        load()
    }

    func copyCurrentFile() {
        guard let url = currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
    }

    /// Asks for the image's folder, or any parent of it. A parent grant (such as the
    /// Home folder) is remembered permanently and covers every folder inside it.
    @discardableResult
    func requestFolderAccess(suggesting directory: URL? = nil) -> Bool {
        let expectedFolder = initialURL.deletingLastPathComponent().standardizedFileURL
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = directory ?? expectedFolder
        panel.prompt = "Grant Access"
        panel.message = "Choose “\(expectedFolder.lastPathComponent)” or any folder that contains it. "
            + "Choosing your Home folder lets VibePhoto open every folder inside it without asking again."
        guard panel.runModal() == .OK, let folder = panel.url?.standardizedFileURL else { return false }
        guard FolderAccessStore.path(folder.path, covers: expectedFolder.path) else {
            errorMessage = "“\(folder.lastPathComponent)” does not contain this image. "
                + "Choose “\(expectedFolder.lastPathComponent)” or one of its parent folders."
            return false
        }
        folderAccess = FolderAccessStore.shared.remember(folder, pinned: folder != expectedFolder)
        needsFolderAccess = false
        load()
        return true
    }

    func requestHomeFolderAccess() {
        requestFolderAccess(suggesting: FolderAccessStore.userHomeDirectory)
    }

    func toggleFavorite() {
        guard let url = currentURL else { return }
        favorites.toggle(url)
        favoriteNotice = FavoriteNotice(added: favorites.contains(url))
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
                reloadCurrentImage(discardingCache: true)
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
                if replacingOriginal {
                    reloadCurrentImage(discardingCache: true)
                } else if collection != nil {
                    collection?.insert(destination, at: index + 1)
                    initialURL = destination
                    load()
                } else {
                    initialURL = destination
                    load()
                }
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
            reloadCurrentImage(discardingCache: true)
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
            decodedImages[url] = nil
            collection?.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
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

    private func wrappedIndex(_ value: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        return (value % items.count + items.count) % items.count
    }

    private func navigate(to requestedIndex: Int) {
        guard items.indices.contains(requestedIndex), requestedIndex != index else { return }
        let requestedURL = items[requestedIndex].url.standardizedFileURL
        if needsFolderAccess, !requestFolderAccess() { return }
        guard let resolvedIndex = items.firstIndex(where: {
            $0.url.standardizedFileURL == requestedURL
        }) else { return }
        index = resolvedIndex
        loadCurrent()
    }

    /// Decodes off the main actor. The previous image stays visible until the new one is
    /// ready, and neighbours are decoded ahead so Previous/Next feel instant.
    private func reloadCurrentImage(discardingCache: Bool = false) {
        guard let url = currentURL else { return }
        loadTask?.cancel()
        if discardingCache { decodedImages[url] = nil }
        if let cached = decodedImages[url] {
            show(cached)
            prefetchNeighbours()
            return
        }
        isLoadingImage = true
        loadTask = Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                ImageLoadingService.loadForDisplay(at: url)
            }.value
            guard let self, !Task.isCancelled, self.currentURL == url else { return }
            self.isLoadingImage = false
            if let loaded {
                self.decodedImages[url] = loaded
                self.show(loaded)
                self.prefetchNeighbours()
            } else {
                self.image = nil
                self.metadata = []
                self.errorMessage = "The image is unsupported or damaged."
            }
        }
    }

    private func show(_ loaded: LoadedImage) {
        isLoadingImage = false
        image = loaded.image
        metadata = loaded.metadata
        lastKnownModificationDate = loaded.modificationDate
    }

    private func prefetchNeighbours() {
        guard items.count > 1, !needsFolderAccess else { return }
        let wanted = Set([index, wrappedIndex(index - 1), wrappedIndex(index + 1)].map { items[$0].url })
        decodedImages = decodedImages.filter { wanted.contains($0.key) }
        for (url, task) in prefetchTasks where !wanted.contains(url) {
            task.cancel()
            prefetchTasks[url] = nil
        }
        for url in wanted where decodedImages[url] == nil && prefetchTasks[url] == nil {
            prefetchTasks[url] = Task { [weak self] in
                let loaded = await Task.detached(priority: .utility) {
                    ImageLoadingService.loadForDisplay(at: url)
                }.value
                guard let self, !Task.isCancelled else { return }
                self.prefetchTasks[url] = nil
                if let loaded { self.decodedImages[url] = loaded }
            }
        }
    }
}
