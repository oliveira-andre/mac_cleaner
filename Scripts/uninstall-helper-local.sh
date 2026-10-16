#!/bin/bash
# Remove the locally-installed root helper (undo install-helper-local.sh).
# Run: sudo Scripts/uninstall-helper-local.sh
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run with sudo."; exit 1; fi

LABEL="io.partnerfleet.maccleaner.helper"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
DEST="/Library/PrivilegedHelperTools/$LABEL"

launchctl bootout system "$PLIST" 2>/dev/null || true
rm -f "$PLIST" "$DEST"
echo "Removed $LABEL."
