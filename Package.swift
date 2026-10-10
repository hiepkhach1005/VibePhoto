// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImageViewer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ImageViewer", targets: ["ImageViewer"])
    ],
    targets: [
        .executableTarget(
            name: "ImageViewer",
            path: "Sources/ImageViewer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ImageViewerTests",
            dependencies: ["ImageViewer"],
            path: "Tests/ImageViewerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
