#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: Scripts/run-app.sh [debug|release]" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release
  BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
else
  swift build
  BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
fi

APP_DIR="$ROOT_DIR/.build/NewsDaily.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/NewsDaily" "$MACOS_DIR/NewsDaily"
cp "$ROOT_DIR/SupportingFiles/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/SupportingFiles/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp -R "$BUILD_DIR/NewsDaily_NewsDaily.bundle" "$RESOURCES_DIR/NewsDaily_NewsDaily.bundle"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

open -n "$APP_DIR"

echo "Launched $APP_DIR"
