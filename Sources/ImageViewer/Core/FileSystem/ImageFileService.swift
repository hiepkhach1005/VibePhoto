@preconcurrency import CoreGraphics
@preconcurrency import ImageIO
import Foundation
import UniformTypeIdentifiers

enum ImageFileServiceError: LocalizedError {
    case cannotEnumerate(URL)

    var errorDescription: String? {
        switch self {
        case .cannotEnumerate(let url):
            "Image Viewer does not have permission to browse \(url.lastPathComponent)."
        }
    }
}

enum ImageFileService {
    private static let commonExtensions: Set<String> = [
        "jpg", "jpeg", "jpe", "png", "heic", "heif", "gif", "tif", "tiff",
        "webp", "bmp", "dib", "ico", "avif", "jp2", "j2k", "dng"
    ]

    static let supportedTypes: [UTType] = {
        let identifiers = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
        return identifiers.compactMap(UTType.init)
    }()

    static func isSupported(_ url: URL) -> Bool {
        guard !url.hasDirectoryPath else { return false }
        let ext = url.pathExtension.lowercased()
        if commonExtensions.contains(ext) { return true }
        if let type = UTType(filenameExtension: ext), type.conforms(to: .image) { return true }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .image) || supportedTypes.contains(type)
        }
        return false
    }

    static func imageItem(for url: URL) -> ImageItem? {
        guard isSupported(url) else { return nil }
        let keys: Set<URLResourceKey> = [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: keys)
        return ImageItem(
            url: url,
            fileSize: Int64(values?.fileSize ?? 0),
            createdAt: values?.creationDate,
            modifiedAt: values?.contentModificationDate
        )
    }

    static func images(in folder: URL, recursive: Bool = false) throws -> [ImageItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey, .contentTypeKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = recursive
            ? [.skipsHiddenFiles, .skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: options
        ) else { throw ImageFileServiceError.cannotEnumerate(folder) }

        var result: [ImageItem] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { throw CancellationError() }
            if let item = imageItem(for: url) { result.append(item) }
        }
        return result
    }

    static func siblingImages(of url: URL) throws -> [ImageItem] {
        try images(in: url.deletingLastPathComponent()).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func subfolders(in folder: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter {
            (try? $0.resourceValues(forKeys: keys).isDirectory) == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func sorted(_ items: [ImageItem], by sort: ImageSort, ascending: Bool) -> [ImageItem] {
        items.sorted { lhs, rhs in
            let order: ComparisonResult
            switch sort {
            case .name:
                order = lhs.name.localizedStandardCompare(rhs.name)
            case .type:
                order = lhs.fileExtension.localizedStandardCompare(rhs.fileExtension)
            case .created:
                order = compare(lhs.createdAt ?? .distantPast, rhs.createdAt ?? .distantPast)
            case .modified:
                order = compare(lhs.modifiedAt ?? .distantPast, rhs.modifiedAt ?? .distantPast)
            case .size:
                order = compare(lhs.fileSize, rhs.fileSize)
            }
            if order == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    private static func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}
