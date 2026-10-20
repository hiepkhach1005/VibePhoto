import Foundation

struct StoredFolderBookmark: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var originalPath: String
    var bookmarkData: Data
    var lastOpenedAt: Date
    /// Broad grants (for example the Home folder) are kept even when the recent list is trimmed.
    var isPinned: Bool?
}

final class SecurityScopedAccess {
    let url: URL
    private let didStart: Bool

    init(url: URL) {
        self.url = url
        didStart = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
}

@MainActor
final class FolderAccessStore: ObservableObject {
    static let shared = FolderAccessStore()

    @Published private(set) var folders: [StoredFolderBookmark] = []
    private let defaultsKey = "folderAccessBookmarks.v1"

    private init() { load() }

    /// The real user home folder; `homeDirectoryForCurrentUser` points inside the sandbox container.
    static var userHomeDirectory: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// True when `grantedPath` is `path` itself or one of its ancestors.
    nonisolated static func path(_ grantedPath: String, covers path: String) -> Bool {
        if grantedPath == "/" || grantedPath == path { return true }
        return path.hasPrefix(grantedPath.hasSuffix("/") ? grantedPath : grantedPath + "/")
    }

    var pinnedFolders: [StoredFolderBookmark] { folders.filter { $0.isPinned == true } }

    /// Resolves a remembered grant for `folder` or any of its ancestors, preferring the closest one.
    func accessCovering(_ folder: URL) -> SecurityScopedAccess? {
        let path = folder.standardizedFileURL.path
        let candidates = folders
            .filter { Self.path($0.originalPath, covers: path) }
            .sorted { $0.originalPath.count > $1.originalPath.count }
        for bookmark in candidates {
            if let (_, access) = resolve(bookmark) { return access }
        }
        return nil
    }

    @discardableResult
    func remember(_ url: URL, pinned: Bool = false) -> SecurityScopedAccess? {
        let normalized = url.standardizedFileURL
        let access = SecurityScopedAccess(url: normalized)
        do {
            let data = try normalized.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.nameKey, .fileResourceIdentifierKey],
                relativeTo: nil
            )
            if let index = folders.firstIndex(where: { $0.originalPath == normalized.path }) {
                folders[index].bookmarkData = data
                folders[index].lastOpenedAt = Date()
                if pinned { folders[index].isPinned = true }
            } else {
                folders.append(.init(
                    id: UUID(), displayName: normalized.lastPathComponent,
                    originalPath: normalized.path, bookmarkData: data, lastOpenedAt: Date(),
                    isPinned: pinned ? true : nil
                ))
            }
            folders.sort { $0.lastOpenedAt > $1.lastOpenedAt }
            trimRecentFolders()
            persist()
            return access
        } catch {
            return access
        }
    }

    func resolve(_ bookmark: StoredFolderBookmark) -> (URL, SecurityScopedAccess)? {
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale
            )
            let access = SecurityScopedAccess(url: url)
            if stale { _ = remember(url) }
            return (url, access)
        } catch {
            return nil
        }
    }

    func unpin(_ bookmark: StoredFolderBookmark) {
        guard let index = folders.firstIndex(where: { $0.id == bookmark.id }) else { return }
        folders[index].isPinned = nil
        trimRecentFolders()
        persist()
    }

    func forget(_ bookmark: StoredFolderBookmark) {
        folders.removeAll { $0.id == bookmark.id }
        persist()
    }

    private func trimRecentFolders() {
        var unpinnedCount = 0
        folders.removeAll { folder in
            guard folder.isPinned != true else { return false }
            unpinnedCount += 1
            return unpinnedCount > 12
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([StoredFolderBookmark].self, from: data) else { return }
        folders = decoded.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
