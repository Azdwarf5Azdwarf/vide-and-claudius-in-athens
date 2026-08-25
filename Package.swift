// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitVisualizer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GitVisualizer", targets: ["GitVisualizer"]),
        .executable(name: "GitVisualizerApp", targets: ["GitVisualizerApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        // Terminal interface. Deliberately does not depend on the UI target so
        // it stays usable without SwiftUI.
        .executableTarget(
            name: "GitVisualizer",
            dependencies: [
                .target(name: "GitVisualizerCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // The macOS window.
        .executableTarget(
            name: "GitVisualizerApp",
            dependencies: [
                .target(name: "GitVisualizerCore"),
                .target(name: "GitVisualizerUI")
            ]
        ),
        .target(
            name: "GitVisualizerCore",
            dependencies: []
        ),
        .target(
            name: "GitVisualizerUI",
            dependencies: [
                .target(name: "GitVisualizerCore")
            ]
        ),
        .testTarget(
            name: "GitVisualizerCoreTests",
            dependencies: [
                .target(name: "GitVisualizerCore")
            ]
        )
    ]
)
