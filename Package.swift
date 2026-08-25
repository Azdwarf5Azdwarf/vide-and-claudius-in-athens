// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitVisualizer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/tuist/XcodeProj", from: "8.0.0")
    ],
    targets: [
        .executableTarget(
            name: "GitVisualizer",
            dependencies: [
                .target(name: "GitVisualizerCore"),
                .target(name: "GitVisualizerUI"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
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
