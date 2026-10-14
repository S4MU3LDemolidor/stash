#!/usr/bin/env bash
# Builds Stash in release mode and assembles build/Stash.app.
#
# Usage: scripts/build-app.sh
# Env:   STASH_VERSION (default 0.1.0), STASH_BUILD (default: git commit count)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Stash"
VERSION="${STASH_VERSION:-0.1.0}"
BUILD_NUMBER="${STASH_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="build/${APP_NAME}.app"

echo "==> Building ${APP_NAME} ${VERSION} (${BUILD_NUMBER})"
swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $BUILD_NUMBER" \
    "$APP/Contents/Info.plist"

# SwiftPM resource bundles of dependencies (localizations, privacy manifests).
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP/Contents/Resources/"
done

echo "==> Signing (ad-hoc)"
# Apple Events (Automation) permissions need a signed app; ad-hoc is enough locally.
# The ad-hoc signature changes on every build, so macOS may ask for permission again
# after a rebuild. Proper Developer ID signing comes later.
codesign --force --deep --sign - --entitlements Support/entitlements.plist "$APP"

echo "==> Done: ${APP}"
