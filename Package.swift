// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibePhoto",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VibePhoto", targets: ["VibePhoto"])
    ],
    targets: [
        .executableTarget(
            name: "VibePhoto",
            path: "Sources/VibePhoto",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VibePhotoTests",
            dependencies: ["VibePhoto"],
            path: "Tests/VibePhotoTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
