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

# The Swift Build engine makes dependencies look for their resource bundles in
# Contents/Resources, where this script puts them. (The older "native" build system looks
# next to the .app instead, which can't be code signed, and would crash the shortcut
# recorder in Settings on any other Mac.)
BUILD_FLAGS=(-c release --build-system swiftbuild)

echo "==> Building ${APP_NAME} ${VERSION} (${BUILD_NUMBER})"
swift build "${BUILD_FLAGS[@]}" --product "$APP_NAME"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"
# Placeholder icon; regenerate with: swift scripts/make-icon.swift
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $BUILD_NUMBER" \
    "$APP/Contents/Info.plist"

# SwiftPM resource bundles of dependencies (localizations, privacy manifests).
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP/Contents/Resources/"
done
if [ ! -d "$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle" ]; then
    echo "error: KeyboardShortcuts' resource bundle is missing; the shortcut recorder would crash." >&2
    exit 1
fi
ACCESSOR="$(find .build -path '*KeyboardShortcuts*' -path '*Release*' -name resource_bundle_accessor.swift 2>/dev/null | head -1)"
if [ -n "$ACCESSOR" ] && ! grep -q "Bundle.main.resourceURL" "$ACCESSOR"; then
    echo "error: this toolchain's SwiftPM doesn't look for resource bundles in Contents/Resources." >&2
    echo "       Use a recent Xcode (see README, Build from source)." >&2
    exit 1
fi

echo "==> Signing (ad-hoc)"
# Apple Events (Automation) permissions need a signed app; ad-hoc is enough locally.
# The ad-hoc signature changes on every build, so macOS may ask for permission again
# after a rebuild. Proper Developer ID signing comes later.
codesign --force --deep --sign - --entitlements Support/entitlements.plist "$APP"

echo "==> Done: ${APP}"
