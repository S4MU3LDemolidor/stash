#!/usr/bin/env bash
# Builds build/Stash.app and packs it into build/Stash-<version>.dmg: open it, drag Stash
# onto the Applications shortcut, done.
#
# Usage: scripts/make-dmg.sh [--skip-build]
# Env:   STASH_VERSION (default 0.1.0), STASH_BUILD (see build-app.sh)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${STASH_VERSION:-0.1.0}"
DMG="build/Stash-${VERSION}.dmg"

if [ "${1:-}" != "--skip-build" ]; then
    scripts/build-app.sh
fi
[ -d build/Stash.app ] || { echo "error: build/Stash.app not found" >&2; exit 1; }

echo "==> Packing ${DMG}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGING="$WORK/Stash"
mkdir -p "$STAGING"
cp -R build/Stash.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

cp Support/AppIcon.icns "$STAGING/.VolumeIcon.icns"

# A writable image first, so the mounted disk can be marked to show the app icon (the flag
# lives on the volume itself), then compressed into the final read-only image.
hdiutil create -volname "Stash" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" > /dev/null
MOUNT="$WORK/mount"
mkdir -p "$MOUNT"
hdiutil attach -nobrowse -noautoopen -mountpoint "$MOUNT" "$WORK/rw.dmg" > /dev/null
if command -v SetFile > /dev/null; then
    SetFile -a C "$MOUNT"
fi
hdiutil detach "$MOUNT" > /dev/null

rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" > /dev/null

echo "==> Done: ${DMG} ($(du -h "$DMG" | cut -f1))"
