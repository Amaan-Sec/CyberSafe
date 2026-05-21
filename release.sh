#!/usr/bin/env bash
# Build a versioned release of the MahaCyber Safe APK.
#
# Reads the current version from .app_version, increments it, runs
# `flutter build apk --release --split-per-abi`, then copies the resulting
# APKs to versionN-<abi>-release.apk and rewrites the landing page links to
# match. Old versionN files are left in place so you can roll back.
#
# Usage:
#   ./release.sh           # bump and build
#   ./release.sh --no-bump # build for the current version (rebuild without bumping)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COUNTER="$ROOT/.app_version"
LANDING="$ROOT/index.html"
APK_DIR="$ROOT/mahacyber_safe_app/build/app/outputs/flutter-apk"
FLUTTER="${FLUTTER:-/home/harsh/development/flutter/bin/flutter}"

# Read current version
[ -f "$COUNTER" ] && source "$COUNTER" || VERSION=0

if [[ "${1:-}" == "--no-bump" ]]; then
  echo "→ Rebuilding without bumping (current = version$VERSION)"
else
  VERSION=$((VERSION + 1))
  echo "→ Building version$VERSION"
fi

echo "→ flutter build apk --release --split-per-abi"
cd "$ROOT/mahacyber_safe_app"
"$FLUTTER" build apk --release --split-per-abi

# Copy outputs to versionN-*.apk
cd "$APK_DIR"
for abi in arm64-v8a armeabi-v7a x86_64; do
  src="app-${abi}-release.apk"
  dst="version${VERSION}-${abi}-release.apk"
  cp "$src" "$dst"
  echo "  → $dst ($(du -h "$dst" | cut -f1))"
done

# Persist new version
echo "VERSION=$VERSION" > "$COUNTER"

# Rewrite landing page version label + links (sed -i replaces all version<N>- with version$VERSION-)
sed -i -E "s|version[0-9]+-(arm64-v8a\|armeabi-v7a\|x86_64)-release\.apk|version${VERSION}-\1-release.apk|g" "$LANDING"
sed -i -E "s|<b id=\"versionLabel\">version[0-9]+</b>|<b id=\"versionLabel\">version${VERSION}</b>|" "$LANDING"

echo
echo "✓ Release version$VERSION ready"
echo "  Landing page now points to:"
grep -oE 'version[0-9]+-[a-z0-9_-]+\.apk' "$LANDING" | sort -u | sed 's/^/    /'
