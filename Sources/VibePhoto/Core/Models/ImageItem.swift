import Foundation

struct ImageItem: Identifiable, Hashable {
    let url: URL
    let fileSize: Int64
    let createdAt: Date?
    let modifiedAt: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.uppercased() }
}

enum ImageSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case type = "Type"
    case created = "Date Created"
    case modified = "Date Modified"
    case size = "File Size"

    var id: String { rawValue }
}

enum ImageGroup: String, CaseIterable, Identifiable {
    case none = "None"
    case folder = "Folder"
    case type = "Type"
    case modifiedMonth = "Modified Month"
    case size = "File Size"

    var id: String { rawValue }
}

struct ImageGroupSection: Identifiable {
    let title: String
    let items: [ImageItem]
    var id: String { title }
}
