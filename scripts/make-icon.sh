#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from Resources/AppIcon-1024.png (if present).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="Resources/AppIcon-1024.png"
[ -f "$SRC" ] || { echo "No $SRC; skipping icon."; exit 0; }
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512; do
    sips -z $sz $sz "$SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    d=$((sz*2)); sips -z $d $d "$SRC" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"
echo "Wrote Resources/AppIcon.icns"
