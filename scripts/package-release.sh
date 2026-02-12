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
SKIP_SIGNING="${SKIP_SIGNING:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

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

# SwiftPM resources are emitted as *.bundle directories. Copy them into the app.
BINARY_DIR="$(cd "$(dirname "$BINARY_PATH")" && pwd)"
RESOURCE_BUNDLES="$(find "$BINARY_DIR" -maxdepth 1 -type d -name '*.bundle' | sort || true)"
if [[ -z "$RESOURCE_BUNDLES" ]]; then
  RESOURCE_BUNDLES="$(find .build -type d -path '*/release/*.bundle' | sort || true)"
fi

if [[ -n "$RESOURCE_BUNDLES" ]]; then
  while IFS= read -r bundle_path; do
    [[ -n "$bundle_path" ]] || continue
    cp -R "$bundle_path" "$APP_BUNDLE/Contents/Resources/"
  done <<< "$RESOURCE_BUNDLES"
fi

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
DIST_APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

resolve_sign_identity() {
  if [[ "$SKIP_SIGNING" == "1" ]]; then
    return 1
  fi

  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "$SIGN_IDENTITY"
    return 0
  fi

  local detected
  detected="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F\" '/Developer ID Application:/{print $2; exit}'
  )"

  if [[ -z "$detected" ]]; then
    return 1
  fi

  echo "$detected"
}

sign_app_bundle() {
  local identity="$1"
  echo "Signing app with: $identity"

  xattr -cr "$DIST_APP_BUNDLE" 2>/dev/null || true

  codesign --force --timestamp --options runtime --sign "$identity" "$DIST_APP_BUNDLE/Contents/MacOS/$APP_NAME"
  codesign --force --deep --timestamp --options runtime --sign "$identity" "$DIST_APP_BUNDLE"

  codesign --verify --deep --strict --verbose=2 "$DIST_APP_BUNDLE"
  spctl --assess --type execute -v "$DIST_APP_BUNDLE" || true
}

notarize_and_staple() {
  local profile="$1"
  local notary_zip="$DIST_DIR/$APP_NAME-notary.zip"

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; cannot notarize." >&2
    exit 1
  fi

  if ! xcrun notarytool help >/dev/null 2>&1; then
    echo "notarytool unavailable; install/update Xcode Command Line Tools." >&2
    exit 1
  fi

  echo "Submitting app for notarization with profile: $profile"
  (
    cd "$DIST_DIR"
    rm -f "$APP_NAME.app.zip" "$notary_zip"
    COPYFILE_DISABLE=1 zip -qryX "$notary_zip" "$APP_NAME.app"
  )

  xcrun notarytool submit "$notary_zip" --keychain-profile "$profile" --wait
  xcrun stapler staple "$DIST_APP_BUNDLE"
  rm -f "$notary_zip"
}

if identity="$(resolve_sign_identity)"; then
  sign_app_bundle "$identity"
else
  echo "No Developer ID Application identity detected. Building unsigned app."
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize_and_staple "$NOTARY_PROFILE"
fi

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
