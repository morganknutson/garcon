#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.1.0}"
APP_NAME="Garcon"
DISPLAY_NAME="Garcon"
BUNDLE_ID="com.morganknutson.garcon"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$DIST_DIR/.work"
ARCH="$(uname -m)"

echo "Building $APP_NAME $VERSION for macOS ($ARCH)..."

rm -rf "$DIST_DIR"
mkdir -p "$WORK_DIR"

swift build -c release --product "$APP_NAME"

BINARY_PATH=""
if [[ -x ".build/release/$APP_NAME" ]]; then
  BINARY_PATH=".build/release/$APP_NAME"
else
  CANDIDATE="$(find .build -type f -path "*/release/$APP_NAME" | head -n 1 || true)"
  if [[ -n "$CANDIDATE" && -x "$CANDIDATE" ]]; then
    BINARY_PATH="$CANDIDATE"
  fi
fi

if [[ -z "$BINARY_PATH" ]]; then
  echo "Could not locate release binary for $APP_NAME." >&2
  exit 1
fi

APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${DISPLAY_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${DISPLAY_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp -R "$APP_BUNDLE" "$DIST_DIR/$APP_NAME.app"

(
  cd "$DIST_DIR"
  xattr -cr "$APP_NAME.app" 2>/dev/null || true
  rm -f "$APP_NAME.app.zip"
  COPYFILE_DISABLE=1 zip -qryX "$APP_NAME.app.zip" "$APP_NAME.app"
  COPYFILE_DISABLE=1 tar -czf "$APP_NAME-macos-$ARCH.tar.gz" "$APP_NAME.app"
  shasum -a 256 "$APP_NAME.app.zip" "$APP_NAME-macos-$ARCH.tar.gz" > SHA256SUMS.txt
)

rm -rf "$WORK_DIR"

echo "Artifacts created:"
echo "  $DIST_DIR/$APP_NAME.app.zip"
echo "  $DIST_DIR/$APP_NAME-macos-$ARCH.tar.gz"
echo "  $DIST_DIR/SHA256SUMS.txt"
