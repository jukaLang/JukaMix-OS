#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

marker="$STATE_DIR/safe-mode"

case "${1:-status}" in
    enable)
        {
            printf 'enabled_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)"
            printf 'reason=%s\n' "${2:-manual}"
        } | jm_atomic_write "$marker"
        printf 'Safe mode enabled.\n'
        ;;
    disable)
        rm -f "$marker"
        printf 'Safe mode disabled.\n'
        ;;
    status)
        if [ -f "$marker" ]; then
            printf 'enabled\n'
            cat "$marker"
        else
            printf 'disabled\n'
        fi
        ;;
    *)
        printf 'Usage: %s {enable [reason]|disable|status}\n' "$0" >&2
        exit 2
        ;;
esac
