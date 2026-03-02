#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="SpeechMore"
BUILD_DIR=".build"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "=== Building $APP_NAME ==="

# Build with SPM
swift build -c release 2>&1

# Locate the built binary
BINARY="$BUILD_DIR/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

echo "=== Creating .app bundle ==="

# Clean previous bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Code sign with stable identity so macOS preserves accessibility permissions across rebuilds
echo "=== Signing ==="
SIGN_IDENTITY="SpeechMore Developer"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    echo "Warning: '$SIGN_IDENTITY' certificate not found, falling back to ad-hoc signing."
    echo "  Accessibility permission will need to be re-granted after each build."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "=== Done ==="
echo "App bundle created at: $APP_BUNDLE"
echo ""

# Install to /Applications
INSTALL_PATH="/Applications/$APP_NAME.app"
echo "=== Installing to $INSTALL_PATH ==="
rm -rf "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"

echo ""
echo "To run: open /Applications/$APP_NAME.app"
echo ""
echo "First launch will automatically prompt for Accessibility permission."
echo "Also set Fn key to 'Do Nothing' in:"
echo "  System Settings > Keyboard > Press fn key to"
