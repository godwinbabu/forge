#!/bin/bash
# Generate Sparkle appcast entry for a release
# Usage: ./Scripts/generate-appcast.sh <dmg-path> <version-tag>

set -euo pipefail

DMG_PATH="${1:?Usage: generate-appcast.sh <dmg-path> <version-tag>}"
VERSION_TAG="${2:?Usage: generate-appcast.sh <dmg-path> <version-tag>}"
VERSION="${VERSION_TAG#v}"  # Strip leading 'v'

DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_NAME=$(basename "$DMG_PATH")
PUB_DATE=$(date -R)

# EdDSA signature (requires SPARKLE_PRIVATE_KEY env var or key file)
if command -v sign_update &>/dev/null; then
    SIGNATURE=$(sign_update "$DMG_PATH" 2>/dev/null || echo "")
else
    echo "Warning: sign_update not found. Skipping EdDSA signature."
    SIGNATURE=""
fi

cat <<EOF
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url="https://github.com/godwinbabu/forge/releases/download/${VERSION_TAG}/${DMG_NAME}"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        length="${DMG_SIZE}"
        type="application/octet-stream"
        ${SIGNATURE:+sparkle:edSignature=\"$SIGNATURE\"}
      />
    </item>
EOF
