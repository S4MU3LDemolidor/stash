#!/usr/bin/env bash
# Builds build/Stash.app, quits any running instance and opens the new one.
set -euo pipefail

cd "$(dirname "$0")/.."

scripts/build-app.sh

# Match on the executable path so we never touch another app that happens to be called "Stash".
PATTERN="Stash.app/Contents/MacOS/Stash"
if pgrep -f "$PATTERN" >/dev/null; then
    echo "==> Quitting running Stash"
    pkill -f "$PATTERN" || true
    for _ in {1..50}; do
        pgrep -f "$PATTERN" >/dev/null || break
        sleep 0.1
    done
fi

echo "==> Launching"
open build/Stash.app
