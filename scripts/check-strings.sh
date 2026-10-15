#!/usr/bin/env bash
# Checks Stash's translations against the code: every string the app shows must be in each
# language's table, and no table may keep strings the app no longer uses. The compiler itself
# lists the strings (-emit-localized-strings), so nothing is missed by a regex.
#
# Usage: scripts/check-strings.sh            check every language
#        scripts/check-strings.sh sync-en    rewrite the English table from the code
#        scripts/check-strings.sh missing pt-BR
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=".build/strings"
mkdir -p "$OUT/data"

# A separate build folder, so the extra compiler flag doesn't rebuild the normal one.
if ! swift build --scratch-path "$OUT/build" --product Stash \
    -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/$OUT/data" \
    > "$OUT/build.log" 2>&1; then
    cat "$OUT/build.log" >&2
    exit 1
fi

python3 scripts/strings.py "${1:-check}" "$OUT/data" Support/Localization "${@:2}"
