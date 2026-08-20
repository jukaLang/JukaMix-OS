#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
export JUKAMIX_ROOT="$TMP"
mkdir -p "$TMP/System/usr/jukamix" "$TMP/System/etc/jukamix"
cp -R "$ROOT/bin" "$ROOT/lib" "$ROOT/migrations" "$TMP/System/usr/jukamix/"
cp "$ROOT/config/jukamix.conf" "$TMP/System/etc/jukamix/jukamix.conf"

"$TMP/System/usr/jukamix/bin/jm-session-run" \
    --system Test --game "$TMP/Game With Spaces.rom" --profile balanced -- sh -c 'exit 7' && exit 1 || code=$?
[ "$code" -eq 7 ]
[ ! -f "$TMP/System/var/jukamix/state/active_session.env" ]
grep -q 'Game With Spaces.rom' "$TMP/System/var/jukamix/state/recent.tsv"
grep -q 'Game With Spaces.rom' "$TMP/System/var/jukamix/state/playtime.tsv"
echo "test_session: PASS"
