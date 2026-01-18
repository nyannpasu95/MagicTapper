#!/bin/bash

# Debug build script for MagicTapper app

APP_NAME="MagicTapper_Debug"
BUNDLE_ID="com.magictapper.app.debug"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "=========================================="
echo "Building MagicTapper (Debug Mode)"
echo "=========================================="

# Clean previous debug build
rm -rf "$APP_PATH"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Compile with debug symbols for current architecture only
echo "📦 Compiling debug version..."
swiftc -o "$APP_PATH/Contents/MacOS/$APP_NAME" \
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
    MultitouchManager.swift \
    MultitouchRestartManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ Debug compilation failed!"
    exit 1
fi

# Create debug Info.plist
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MagicTapper Debug</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1-debug</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MagicTapper requires accessibility permissions to detect taps on your Magic Mouse and simulate clicks.</string>
</dict>
</plist>
EOF

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
