#!/bin/bash
set -e

APP_NAME="Indigo"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Copy NDI dylib into bundle
if [ -f "/Library/NDI SDK for Apple/lib/macOS/libndi.dylib" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    cp "/Library/NDI SDK for Apple/lib/macOS/libndi.dylib" "$APP_BUNDLE/Contents/Frameworks/"
    # Update rpath so the binary finds the dylib in Frameworks
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Indigo</string>
    <key>CFBundleDisplayName</key>
    <string>Indigo</string>
    <key>CFBundleIdentifier</key>
    <string>com.jonasjohansson.indigo</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>Indigo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Indigo needs screen recording to capture web content</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Indigo uses NDI to send video over the network</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_ndi._tcp</string>
    </array>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Done! App bundle created at: $(pwd)/$APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
