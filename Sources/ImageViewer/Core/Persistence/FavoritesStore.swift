import Foundation

struct FavoriteRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var path: String
    var displayName: String
    var bookmarkData: Data?
    var resourceIdentifier: String?
    var addedAt: Date
}

struct ResolvedFavorite: Identifiable, Hashable {
    let record: FavoriteRecord
    let url: URL?
    var id: UUID { record.id }
    var isMissing: Bool { url == nil }
}

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var records: [FavoriteRecord] = []
    private let storageKey = "favoriteRecords.v2"
    private let legacyKey = "favoriteImagePaths"

    private init() {
        load()
        migrateLegacyPaths()
    }

    func contains(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return records.contains { $0.path == path }
    }

    func toggle(_ url: URL) {
        let normalized = url.standardizedFileURL
        if let index = records.firstIndex(where: { $0.path == normalized.path }) {
            records.remove(at: index)
        } else {
            records.insert(makeRecord(for: normalized), at: 0)
        }
        persist()
    }

    func remove(_ record: FavoriteRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func resolvedFavorites() -> [ResolvedFavorite] {
        records.map { record in
            if let data = record.bookmarkData {
                var stale = false
                if let url = try? URL(
                    resolvingBookmarkData: data, options: [.withoutUI],
                    relativeTo: nil, bookmarkDataIsStale: &stale
                ), FileManager.default.fileExists(atPath: url.path) {
                    if stale { refresh(record, with: url) }
                    return ResolvedFavorite(record: record, url: url)
                }
            }
            let fallback = URL(fileURLWithPath: record.path)
            return ResolvedFavorite(record: record, url: FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil)
        }
    }

    private func makeRecord(for url: URL) -> FavoriteRecord {
        let bookmark = try? url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: [.fileResourceIdentifierKey], relativeTo: nil
        )
        let identifier = (try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier)
            .map { String(describing: $0) }
        return .init(
            id: UUID(), path: url.path, displayName: url.lastPathComponent,
            bookmarkData: bookmark, resourceIdentifier: identifier, addedAt: Date()
        )
    }

    private func refresh(_ record: FavoriteRecord, with url: URL) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        let refreshed = makeRecord(for: url)
        records[index].path = refreshed.path
        records[index].displayName = refreshed.displayName
        records[index].bookmarkData = refreshed.bookmarkData
        records[index].resourceIdentifier = refreshed.resourceIdentifier
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteRecord].self, from: data) else { return }
        records = decoded
    }

    private func migrateLegacyPaths() {
        let paths = UserDefaults.standard.stringArray(forKey: legacyKey) ?? []
        for path in paths where !records.contains(where: { $0.path == path }) {
            records.append(makeRecord(for: URL(fileURLWithPath: path)))
        }
        if !paths.isEmpty {
            UserDefaults.standard.removeObject(forKey: legacyKey)
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
