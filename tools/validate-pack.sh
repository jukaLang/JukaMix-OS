#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail=0

find "$ROOT/bin" "$ROOT/lib" "$ROOT/migrations" -type f | while IFS= read -r file; do
    sh -n "$file" || exit 1
done

# Scan only the pack's own code, not the bundled OS image (whose legit scripts
# occasionally remove specific files, e.g. old firmware blobs).
PACK_DIRS="$ROOT/bin $ROOT/lib $ROOT/migrations $ROOT/config $ROOT/tools $ROOT/scripts $ROOT/tests"

if grep -R -n -E '(^|[[:space:]])eval([[:space:]]|$)' "$ROOT/bin" "$ROOT/lib"; then
    echo "unsafe eval found" >&2
    fail=1
fi
if grep -R -n -E 'rm -rf /|chmod 777|chmod -R 777' $PACK_DIRS --exclude='validate-pack.sh' 2>/dev/null; then
    echo "unsafe destructive pattern found" >&2
    fail=1
fi

required="README.md install.sh uninstall.sh config/jukamix.conf bin/jm-session-run bin/jm-doctor"
for rel in $required; do
    [ -f "$ROOT/$rel" ] || { echo "missing: $rel" >&2; fail=1; }
done
exit "$fail"
