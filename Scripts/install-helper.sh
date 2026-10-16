#!/bin/bash
# Assemble + sign the helper into the app bundle so it can be registered as a
# root daemon via SMAppService. This does NOT modify /Library and does NOT
# register the daemon — that happens from the app at runtime
# (SMAppService.daemon(plistName:).register()), which prompts the user to
# approve it in System Settings > General > Login Items.
#
# Prerequisites you must supply:
#   1. Set IPC.teamIdentifier in Sources/IPCProtocol/IPCProtocol.swift to your
#      Developer ID Team ID (the client/helper requirements pin it).
#   2. export DEV_ID="Developer ID Application: Your Name (TEAMID)"
#
# Usage: Scripts/install-helper.sh /path/to/MacCleaner.app
set -euo pipefail

APP="${1:?usage: install-helper.sh /path/to/MacCleaner.app}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${DEV_ID:-}" ]]; then
  echo "DEV_ID not set — refusing to install an unsigned root helper."
  echo "SMAppService requires valid Developer ID signing; see header for setup."
  exit 1
fi

swift build -c release
HELPER="$HERE/.build/release/MacCleanerHelper"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchDaemons"
cp "$HELPER" "$APP/Contents/MacOS/MacCleanerHelper"
cp "$HERE/Scripts/io.partnerfleet.maccleaner.helper.plist" \
   "$APP/Contents/Library/LaunchDaemons/"

# Hardened-runtime sign the helper, then the app bundle, with the same Team ID.
codesign --force --options runtime --timestamp \
  --sign "$DEV_ID" "$APP/Contents/MacOS/MacCleanerHelper"
codesign --force --options runtime --timestamp \
  --sign "$DEV_ID" "$APP"

echo "Helper staged + signed into $APP."
echo "Register it from the app with:"
echo '    try SMAppService.daemon(plistName: "io.partnerfleet.maccleaner.helper.plist").register()'
echo "then approve in System Settings > General > Login Items."
