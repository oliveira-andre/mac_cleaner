#!/bin/bash
# Build MacCleaner.app locally and AD-HOC sign it — no Apple Developer Program,
# no $99/yr. The resulting app runs on THIS Mac. It is not notarized, so it
# can't be distributed to other people without Gatekeeper warnings; that's the
# only thing the paid program buys you.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HERE/build/MacCleaner.app"
CONFIG="${1:-debug}"   # debug | release

echo "Building ($CONFIG)..."
if [[ "$CONFIG" == "release" ]]; then swift build -c release; else swift build; fi
BIN="$HERE/.build/$CONFIG/MacCleanerApp"

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacCleaner"

# App icon (generate once, then reuse).
if [[ ! -f "$HERE/build/AppIcon.icns" ]]; then
  swift "$HERE/Scripts/make-icon.swift" "$HERE/build/AppIcon.icns" sparkles
fi
cp "$HERE/build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>MacCleaner</string>
    <key>CFBundleDisplayName</key><string>MacCleaner</string>
    <key>CFBundleIdentifier</key><string>io.partnerfleet.maccleaner</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleExecutable</key><string>MacCleaner</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Signature' || true

echo
echo "Done: $APP"
echo "Run it with:  open \"$APP\"   (or double-click in Finder)"
