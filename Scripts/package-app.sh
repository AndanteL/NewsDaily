#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/NewsDaily.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/NewsDaily-macOS.zip"

cd "$ROOT_DIR"

swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/NewsDaily" "$MACOS_DIR/NewsDaily"
cp "$ROOT_DIR/SupportingFiles/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/SupportingFiles/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp -R "$BUILD_DIR/NewsDaily_NewsDaily.bundle" "$RESOURCES_DIR/NewsDaily_NewsDaily.bundle"

if grep -R -I -n -E "sk-[A-Za-z0-9_]{8,}|AIza[0-9A-Za-z_-]{20,}|AKIA[0-9A-Z]{16}" "$APP_DIR" >/tmp/newsdaily-secret-scan.txt; then
  echo "Potential secret-like value found in app bundle:" >&2
  cat /tmp/newsdaily-secret-scan.txt >&2
  exit 1
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Packaged app: $APP_DIR"
echo "Zip archive:  $ZIP_PATH"
echo "User config/API keys are stored at runtime outside the app bundle:"
echo "  ~/Library/Application Support/NewsDaily/NewsDaily.store"
