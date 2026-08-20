#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

report="$STATE_DIR/health-report.txt"
root=$(jm_root)

{
    printf 'JukaMix health report\n'
    printf 'Generated: %s\n' "$(date 2>/dev/null || :)"
    printf 'Kernel: %s\n' "$(uname -a 2>/dev/null || :)"
    printf 'Root: %s\n\n' "$root"
    printf '[Storage]\n'
    df -Pk "$root" 2>/dev/null || :
    df -Pi "$root" 2>/dev/null || :
    printf '\n[Memory]\n'
    cat /proc/meminfo 2>/dev/null | head -n 12 || :
    printf '\n[Thermal]\n'
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$zone" ] && printf '%s=%s\n' "$zone" "$(cat "$zone")"
    done
    printf '\n[Profiles]\n'
    "$SELF_DIR/profilectl.sh" status 2>/dev/null || :
    printf '\n[Sessions]\n'
    cat "$STATE_DIR/last-session" 2>/dev/null || printf 'No completed session.\n'
    printf '\n[Safe mode]\n'
    "$SELF_DIR/safe-mode.sh" status 2>/dev/null || :
} | jm_atomic_write "$report"

cat "$report"
