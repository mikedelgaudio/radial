#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ControlRing"
CONFIG="${1:-release}"
BIN_DIR=".build/${CONFIG}"
OUT="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> assembling ${OUT}"
rm -rf "${OUT}"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${OUT}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${OUT}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${OUT}/Contents/Resources/AppIcon.icns"
fi

echo "==> ad-hoc codesign"
codesign --force --deep --sign - "${OUT}"

echo "==> done: ${OUT}"
echo "Launch with: open \"${OUT}\""
