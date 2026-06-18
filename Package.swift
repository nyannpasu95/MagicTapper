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
            path: ".",
            exclude: [
                "AppIcon.icns",
                "AppDelegate.swift",
                "CHANGELOG.md",
                "DEBUG_GUIDE.md",
                "Info.plist",
                "LICENSE",
                "MagicTapper.png",
                "MultitouchBridge.h",
                "MultitouchManager.swift",
                "MouseSpeedIOKitBackend.swift",
                "OPTIMIZATION.md",
                "PointerSpeedMenuView.swift",
                "README.md",
                "README_ja.md",
                "README_zh.md",
                "TESTING.md",
                "build-debug.sh",
                "build.sh",
                "debug-run.sh",
                "install-final.sh",
                "main.swift",
                "magictapper-dark.png",
                "magictapper-light.png",
                "newfeature.md",
                "quick-test.sh",
                "run_tests.sh",
                "test-and-install.sh",
                "AppIcon.iconset",
                "Tests",
                "build"
            ],
            sources: [
                "Constants.swift",
                "MouseSpeedManager.swift",
                "MultitouchRestartManager.swift",
                "TapConfiguration.swift",
                "TapDetector.swift"
            ]
        ),
        .testTarget(
            name: "MagicTapperTests",
            dependencies: ["MagicTapperLib"],
            path: "Tests"
        )
    ]
)
