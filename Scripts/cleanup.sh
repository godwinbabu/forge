#!/bin/bash
# Forge cleanup script — installed as LaunchDaemon by ForgeHelper
# Checks manifest expiry and removes PF rules when block has ended
set -euo pipefail

MANIFEST="/Library/Application Support/Forge/manifest.json"
ANCHOR_FILE="/etc/pf.anchors/app.forge.block"
PF_CONF="/etc/pf.conf"
ANCHOR_NAME="app.forge.block"

if [ ! -f "$MANIFEST" ]; then
    exit 0
fi

# Read end date from manifest
END_DATE=$(python3 -c "
import json, sys
with open('$MANIFEST') as f:
    m = json.load(f)
print(m.get('endDate', ''))
" 2>/dev/null || echo "")

if [ -z "$END_DATE" ]; then
    exit 0
fi

# Check if block has expired
NOW=$(date -u +%s)
END=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$END_DATE" +%s 2>/dev/null || echo "0")

if [ "$NOW" -lt "$END" ]; then
    # Block still active — verify PF anchor exists, re-add if missing
    if ! pfctl -a "$ANCHOR_NAME" -sr 2>/dev/null | grep -q .; then
        if [ -f "$ANCHOR_FILE" ]; then
            pfctl -a "$ANCHOR_NAME" -f "$ANCHOR_FILE" 2>/dev/null || true
        fi
    fi
    exit 0
fi

# Block expired — clean up
# 1. Remove PF anchor rules
pfctl -a "$ANCHOR_NAME" -F all 2>/dev/null || true

# 2. Remove anchor file
rm -f "$ANCHOR_FILE"

# 3. Strip anchor reference from pf.conf
if grep -q "$ANCHOR_NAME" "$PF_CONF" 2>/dev/null; then
    sed -i '' "/$ANCHOR_NAME/d" "$PF_CONF"
    pfctl -f "$PF_CONF" 2>/dev/null || true
fi

# 4. Remove manifest
rm -f "$MANIFEST"

# 5. Remove self (LaunchDaemon)
PLIST="/Library/LaunchDaemons/app.forge.cleanup.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -f "$0"
