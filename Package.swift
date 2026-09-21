// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MagicTapper",
    platforms: [
        .macOS(.v13)
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
                "ZoomScrollFilter.swift",
                "ZoomDiagnosticWindow.swift",
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
                "SettingsWindowController.swift",
                "build-debug.sh",
                "build.sh",
                "debug-run.sh",
                "diagnose-zoom.sh",
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
                "EventSynthesizer.swift",
                "ZoomGestureDetector.swift",
                "ZoomEventSynthesizer.swift",
                "ZoomDiagnostics.swift",
                "ZoomCoordinator.swift",

                "MouseSpeedManager.swift",
                "MultitouchDeviceMonitor.swift",
                "MultitouchRestartManager.swift",
                "MultitouchDeviceClassifier.swift",
                "TapConfiguration.swift",
                "TapDetector.swift"
            ]
        ),
        .testTarget(
            name: "MagicTapperTests",
            dependencies: ["MagicTapperLib"],
            path: "Tests",
            exclude: ["ScriptWorkflowTests.py"]
        )
    ]
)
