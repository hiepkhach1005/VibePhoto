import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var rootFolder: URL?
    @Published var selectedFolder: URL?
    @Published var images: [ImageItem] = []
    @Published var isLoading = false
    @Published var recursive = UserDefaults.standard.bool(forKey: "includeSubfolders") {
        didSet { UserDefaults.standard.set(recursive, forKey: "includeSubfolders") }
    }
    @Published var sort: ImageSort = .name
    @Published var ascending = true
    @Published var group: ImageGroup = .none
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var selectedExtension: String?
    @Published private(set) var showingFavorites = false
    @Published private(set) var missingFavorites: [ResolvedFavorite] = []

    private var folderAccess: SecurityScopedAccess?
    private var scanTask: Task<Void, Never>?
    private let folderMonitor = FolderMonitor()
    private var monitorReloadTask: Task<Void, Never>?

    func openFolder(_ url: URL) {
        scanTask?.cancel()
        folderAccess = FolderAccessStore.shared.remember(url)
        rootFolder = url
        selectedFolder = url
        showingFavorites = false
        beginMonitoring(url)
        reload()
    }

    func openRememberedFolder(_ bookmark: StoredFolderBookmark) {
        guard let (url, access) = FolderAccessStore.shared.resolve(bookmark) else {
            errorMessage = "The saved folder permission is no longer valid. Please choose the folder again."
            return
        }
        folderAccess = access
        rootFolder = url
        selectedFolder = url
        showingFavorites = false
        beginMonitoring(url)
        reload()
    }

    func selectFolder(_ url: URL) {
        selectedFolder = url
        showingFavorites = false
        beginMonitoring(url)
        reload()
    }

    func showFavorites() {
        scanTask?.cancel()
        showingFavorites = true
        selectedFolder = nil
        folderMonitor.stop()
        let resolved = FavoritesStore.shared.resolvedFavorites()
        missingFavorites = resolved.filter(\.isMissing)
        images = resolved.compactMap(\.url).compactMap(ImageFileService.imageItem)
        applySort()
    }

    func reload() {
        guard let folder = selectedFolder else { return }
        isLoading = true
        errorMessage = nil
        let recursive = recursive
        let sort = sort
        let ascending = ascending
        scanTask?.cancel()
        scanTask = Task {
            do {
                let worker = Task.detached {
                    try ImageFileService.images(in: folder, recursive: recursive)
                }
                let loaded = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard !Task.isCancelled else { return }
                images = ImageFileService.sorted(loaded, by: sort, ascending: ascending)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                images = []
            }
            isLoading = false
        }
    }

    var filteredImages: [ImageItem] {
        images.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedExtension == nil || item.fileExtension == selectedExtension
            return matchesSearch && matchesType
        }
    }

    var availableExtensions: [String] {
        Array(Set(images.map(\.fileExtension))).sorted()
    }

    var groupedImages: [ImageGroupSection] {
        guard group != .none else { return [.init(title: "", items: filteredImages)] }
        let grouped = Dictionary(grouping: filteredImages, by: groupTitle)
        return grouped.keys.sorted().map { .init(title: $0, items: grouped[$0] ?? []) }
    }

    func refreshCurrentCollection() {
        if showingFavorites { showFavorites() } else { reload() }
    }

    private func applySort() {
        images = ImageFileService.sorted(images, by: sort, ascending: ascending)
    }

    private func groupTitle(for item: ImageItem) -> String {
        switch group {
        case .none: return ""
        case .folder: return item.url.deletingLastPathComponent().lastPathComponent
        case .type: return item.fileExtension.isEmpty ? "Other" : item.fileExtension
        case .modifiedMonth:
            guard let date = item.modifiedAt else { return "Unknown date" }
            return date.formatted(.dateTime.year().month(.wide))
        case .size:
            switch item.fileSize {
            case ..<1_000_000: return "Under 1 MB"
            case ..<10_000_000: return "1–10 MB"
            case ..<100_000_000: return "10–100 MB"
            default: return "100 MB and over"
            }
        }
    }

    private func beginMonitoring(_ folder: URL) {
        folderMonitor.start(url: folder) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.monitorReloadTask?.cancel()
                self.monitorReloadTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled else { return }
                    self?.reload()
                }
            }
        }
    }
}
