#!/bin/bash
set -euo pipefail

# Debug build script for MagicTapper app

APP_NAME="MagicTapper_Debug"
BUNDLE_ID="com.magictapper.app.debug"
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
echo "Building MagicTapper (Debug Mode)"
echo "=========================================="

# Clean previous debug build
rm -rf "$APP_PATH"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
mkdir -p "$MODULE_CACHE"

# Compile with debug symbols for current architecture only
echo "📦 Compiling debug version..."
"$SWIFTC" -o "$APP_PATH/Contents/MacOS/$APP_NAME" \
    -sdk "$SDKROOT" \
    -Xcc "-fmodules-cache-path=$MODULE_CACHE" \
    -g \
    -Onone \
    -D DEBUG \
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
    MouseSpeedManager.swift \
    MouseSpeedIOKitBackend.swift \
    PointerSpeedMenuView.swift \
    MultitouchManager.swift \
    MultitouchRestartManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ Debug compilation failed!"
    exit 1
fi

# Create debug Info.plist from the shared app plist to avoid duplicate metadata.
cp Info.plist "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName MagicTapper Debug" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.1-debug" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" "$APP_PATH/Contents/Info.plist"

# Copy app icon
cp AppIcon.icns "$APP_PATH/Contents/Resources/"

# Sign the app
echo "🔐 Codesigning debug app..."
codesign --force --deep --sign - "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Codesigning failed!"
    exit 1
fi

echo ""
echo "✅ Debug build complete!"
echo ""
echo "App location: $APP_PATH"
echo ""
echo "To run with console output:"
echo "  $APP_PATH/Contents/MacOS/$APP_NAME"
echo ""
echo "To run as app:"
echo "  open $APP_PATH"
echo ""
