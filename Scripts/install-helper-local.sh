#!/bin/bash
# LOCAL-ONLY install of the root helper — no Apple Developer Program.
#
# Instead of SMAppService (which requires real Developer ID signing), this
# installs the helper as a plain root LaunchDaemon via sudo. For local use the
# helper runs WITHOUT the code-signing-requirement pin (it can't match an
# ad-hoc signature), so access is gated only by the daemon being root-installed
# and the Mach service ACL. Do NOT ship this configuration to other people.
#
# Run:   sudo Scripts/install-helper-local.sh
# Undo:  sudo Scripts/uninstall-helper-local.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Run with sudo."; exit 1; fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="io.partnerfleet.maccleaner.helper"
DEST="/Library/PrivilegedHelperTools/$LABEL"
PLIST="/Library/LaunchDaemons/$LABEL.plist"

echo "Building helper (release)..."
sudo -u "${SUDO_USER:-$USER}" swift build -c release --package-path "$HERE"
# Build a local helper that skips the signing-requirement pin.
cp "$HERE/.build/release/MacCleanerHelper" "$DEST.tmp"
mkdir -p /Library/PrivilegedHelperTools
mv "$DEST.tmp" "$DEST"
chown root:wheel "$DEST"; chmod 755 "$DEST"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>$DEST</string><string>--local</string></array>
    <key>MachServices</key><dict><key>$LABEL</key><true/></dict>
</dict></plist>
PLISTEOF
chown root:wheel "$PLIST"; chmod 644 "$PLIST"

launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
echo "Installed + bootstrapped $LABEL. Test with: MacCleanerUninstall --app X --trash --use-helper"
