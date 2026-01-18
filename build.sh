#!/bin/bash

# Build script for MagicTapper app (Production)

APP_NAME="MagicTapper"
BUNDLE_ID="com.magictapper.app"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "=========================================="
echo "Building MagicTapper (Universal Binary)"
echo "=========================================="

# Clean previous build
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Compile for Apple Silicon (arm64)
echo "📦 Compiling for Apple Silicon (arm64)..."
swiftc -o "$BUILD_DIR/${APP_NAME}_arm64" \
    -target arm64-apple-macos13.0 \
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
    MultitouchManager.swift \
    MultitouchRestartManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ arm64 compilation failed!"
    exit 1
fi

# Compile for Intel (x86_64)
echo "📦 Compiling for Intel (x86_64)..."
swiftc -o "$BUILD_DIR/${APP_NAME}_x86_64" \
    -target x86_64-apple-macos13.0 \
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
    MultitouchManager.swift \
    MultitouchRestartManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ x86_64 compilation failed!"
    exit 1
fi

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
echo "  • Launch at Login functionality"
echo "  • Enhanced menu bar with status display"
echo ""
echo "To run the app:"
echo "  open $APP_PATH"
echo ""
echo "To install the app (copy to Applications):"
echo "  cp -r $APP_PATH /Applications/"
echo ""
