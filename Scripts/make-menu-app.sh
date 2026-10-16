#!/bin/bash
# Build MacCleanerMenu.app — the menu-bar ("top right") health addon — and
# ad-hoc sign it (no Apple Developer account). It's an LSUIElement agent: no
# Dock icon, just a status item you click for live Mac details.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HERE/build/MacCleanerMenu.app"
CONFIG="${1:-debug}"

echo "Building ($CONFIG)..."
if [[ "$CONFIG" == "release" ]]; then swift build -c release; else swift build; fi
BIN="$HERE/.build/$CONFIG/MacCleanerMenu"

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacCleanerMenu"

if [[ ! -f "$HERE/build/MenuIcon.icns" ]]; then
  swift "$HERE/Scripts/make-icon.swift" "$HERE/build/MenuIcon.icns" "gauge.with.dots.needle.33percent"
fi
cp "$HERE/build/MenuIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>MacCleaner Menu</string>
    <key>CFBundleIdentifier</key><string>io.partnerfleet.maccleaner.menu</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleExecutable</key><string>MacCleanerMenu</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
echo
echo "Done: $APP"
echo "Launch it (menu-bar icon appears top-right):  open \"$APP\""
echo "Keep it running at login:  System Settings > General > Login Items > +"
