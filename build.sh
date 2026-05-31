#!/bin/bash
set -euo pipefail

# Build script for MagicTapper app (Production)

APP_NAME="MagicTapper"
BUNDLE_ID="com.magictapper.app"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
MODULE_CACHE="$BUILD_DIR/clang-module-cache"
XCRUN="/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun"
SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"

if [ ! -x "$SWIFTC" ]; then
    SWIFTC="swiftc"
fi

if [ -x "$XCRUN" ]; then
    SDKROOT="$("$XCRUN" --sdk macosx --show-sdk-path)"
else
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
fi

echo "=========================================="
echo "Building MagicTapper (Universal Binary)"
echo "=========================================="

# Clean previous build
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"
mkdir -p "$MODULE_CACHE"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

compile_arch() {
    local arch="$1"
    local label="$2"
    local output="$BUILD_DIR/${APP_NAME}_${arch}"

    echo "📦 Compiling for $label ($arch)..."
    "$SWIFTC" -O -o "$output" \
    -sdk "$SDKROOT" \
    -Xcc "-fmodules-cache-path=$MODULE_CACHE" \
    -target "${arch}-apple-macos13.0" \
    -import-objc-header MultitouchBridge.h \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework ServiceManagement \
    -framework IOKit \
    -F /System/Library/PrivateFrameworks \
    -framework MultitouchSupport \
    -Xlinker -rpath -Xlinker /System/Library/PrivateFrameworks \
    Constants.swift \
    TapConfiguration.swift \
    TapDetector.swift \
    MouseSpeedManager.swift \
    MouseSpeedIOKitBackend.swift \
    PointerSpeedMenuView.swift \
    MultitouchManager.swift \
    MultitouchRestartManager.swift \
    AppDelegate.swift \
    main.swift
}

compile_arch "arm64" "Apple Silicon"
compile_arch "x86_64" "Intel"

# Create universal binary
echo "🔗 Creating universal binary..."
lipo -create \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64" \
    -output "$APP_PATH/Contents/MacOS/$APP_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create universal binary!"
    exit 1
fi

# Clean up temporary files
rm "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

# Copy Info.plist
cp Info.plist "$APP_PATH/Contents/"

# Copy app icon
cp AppIcon.icns "$APP_PATH/Contents/Resources/"

# Ad-hoc sign the app bundle so macOS Accessibility permissions persist
echo ""
echo "🔐 Codesigning app bundle..."
codesign --force --deep --sign - "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Codesigning failed!"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ UNIVERSAL BINARY BUILD COMPLETE!"
echo "=========================================="
echo ""
echo "App location: $APP_PATH"
echo "Architectures: arm64 (Apple Silicon) + x86_64 (Intel)"
echo ""
echo "New Features in v1.1:"
echo "  • Advanced gesture recognition with state machine"
echo "  • Right-click detection (hold >0.1s)"
echo "  • Double-tap drag and drop support"
echo "  • Pointer speed slider"
echo "  • Launch at Login functionality"
echo "  • Enhanced menu bar with status display"
echo ""
echo "To run the app:"
echo "  open $APP_PATH"
echo ""
echo "To install the app (copy to Applications):"
echo "  cp -r $APP_PATH /Applications/"
echo ""
