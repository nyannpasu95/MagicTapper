// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MagicTapper",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MagicTapperLib",
            targets: ["MagicTapperLib"]
        )
    ],
    targets: [
        .target(
            name: "MagicTapperLib",
            dependencies: [],
            path: "Sources",
            sources: ["TapDetector.swift", "AppDelegate.swift"]
        ),
        .testTarget(
            name: "MagicTapperTests",
            dependencies: ["MagicTapperLib"],
            path: "Tests"
        )
    ]
)
