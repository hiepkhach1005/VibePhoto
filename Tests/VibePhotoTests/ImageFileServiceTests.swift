import Foundation
import Testing
@testable import VibePhoto

struct ImageFileServiceTests {
    @Test func sortByNameUsesFinderLikeOrdering() {
        let folder = URL(fileURLWithPath: "/tmp")
        let items = [
            ImageItem(url: folder.appendingPathComponent("image10.jpg"), fileSize: 10, createdAt: nil, modifiedAt: nil),
            ImageItem(url: folder.appendingPathComponent("image2.jpg"), fileSize: 20, createdAt: nil, modifiedAt: nil)
        ]
        let result = ImageFileService.sorted(items, by: .name, ascending: true)
        #expect(result.map(\.name) == ["image2.jpg", "image10.jpg"])
    }

    @Test func sortBySizeDescending() {
        let folder = URL(fileURLWithPath: "/tmp")
        let small = ImageItem(url: folder.appendingPathComponent("small.png"), fileSize: 10, createdAt: nil, modifiedAt: nil)
        let large = ImageItem(url: folder.appendingPathComponent("large.png"), fileSize: 100, createdAt: nil, modifiedAt: nil)
        #expect(ImageFileService.sorted([small, large], by: .size, ascending: false).map(\.name) == ["large.png", "small.png"])
    }
}
