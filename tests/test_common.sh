#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
export JUKAMIX_ROOT="$TMP"
mkdir -p "$TMP/System/etc/jukamix"
cp "$ROOT/config/jukamix.conf" "$TMP/System/etc/jukamix/jukamix.conf"
. "$ROOT/lib/common.sh"

jm_init_dirs
printf 'hello\n' | jm_atomic_write "$JM_STATE/atomic.txt"
[ "$(cat "$JM_STATE/atomic.txt")" = hello ]
[ "$(jm_safe_id 'a path with spaces')" -gt 0 ]
jm_is_uint 123
! jm_is_uint '12x'
jm_lock_acquire test 0
! jm_lock_acquire test 0
jm_lock_release test
echo "test_common: PASS"
