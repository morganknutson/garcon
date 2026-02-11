#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TAG="${1:-v0.1.0}"
if [[ "$TAG" != v* ]]; then
  echo "Tag must start with 'v' (example: v0.1.0)." >&2
  exit 1
fi

VERSION="${TAG#v}"
ARCH="$(uname -m)"
APP_ZIP="dist/Garcon.app.zip"
APP_TAR="dist/Garcon-macos-$ARCH.tar.gz"
SUMS_FILE="dist/SHA256SUMS.txt"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

"$ROOT_DIR/scripts/package-release.sh" "$VERSION"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "Release $TAG"
fi

git push origin HEAD
git push origin "$TAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT

cat > "$NOTES_FILE" <<EOF
## Garcon $TAG

### Downloads

- \`Garcon.app.zip\` for direct install on macOS
- \`Garcon-macos-$ARCH.tar.gz\` alternate archive
- \`SHA256SUMS.txt\` checksums

### Install

1. Download \`Garcon.app.zip\`
2. Unzip and move \`Garcon.app\` to \`/Applications\`
3. Launch Garcon from Applications
EOF

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$APP_ZIP" "$APP_TAR" "$SUMS_FILE" --clobber
  gh release edit "$TAG" --title "Garcon $TAG" --notes-file "$NOTES_FILE"
else
  gh release create "$TAG" "$APP_ZIP" "$APP_TAR" "$SUMS_FILE" \
    --title "Garcon $TAG" \
    --notes-file "$NOTES_FILE"
fi

echo "Release published: $TAG"
