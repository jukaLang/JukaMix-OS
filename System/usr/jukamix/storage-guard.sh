#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

target=${1:-$(jm_root)}
free_kb=$(df -Pk "$target" 2>/dev/null | awk 'NR==2 {print $4}')
free_inodes=$(df -Pi "$target" 2>/dev/null | awk 'NR==2 {print $4}')
free_kb=${free_kb:-0}
free_inodes=${free_inodes:-0}
required_kb=$((MIN_FREE_MB * 1024))
failed=0

probe="$STATE_DIR/.write-test.$$"
if ! (umask 077; printf test > "$probe") 2>/dev/null; then
    printf 'ERROR: storage is not writable: %s\n' "$target" >&2
    failed=1
else
    rm -f "$probe"
fi

if [ "$free_kb" -lt "$required_kb" ]; then
    printf 'ERROR: only %s KB free; %s KB required.\n' "$free_kb" "$required_kb" >&2
    failed=1
fi

if [ "$free_inodes" -gt 0 ] && [ "$free_inodes" -lt "$MIN_FREE_INODES" ]; then
    printf 'ERROR: only %s inodes free; %s required.\n' "$free_inodes" "$MIN_FREE_INODES" >&2
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    jm_log storage-guard "failed target=$target free_kb=$free_kb free_inodes=$free_inodes"
    exit 1
fi

printf 'Storage OK: %s KB and %s inodes free.\n' "$free_kb" "$free_inodes"
