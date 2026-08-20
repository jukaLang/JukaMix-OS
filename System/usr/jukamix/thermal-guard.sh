#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

lock="$STATE_DIR/thermal-guard.lock"
jm_lock "$lock" || exit 0
trap 'jm_unlock "$lock"' EXIT HUP INT TERM

read_temp_c() {
    hottest=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$zone" ] || continue
        raw=$(jm_read_int "$zone")
        [ "$raw" -gt 1000 ] && raw=$((raw / 1000))
        [ "$raw" -gt "$hottest" ] && hottest=$raw
    done
    printf '%s\n' "$hottest"
}

throttled=0
while :; do
    temp=$(read_temp_c)
    if [ "$temp" -ge "$THERMAL_HOT_C" ] && [ "$throttled" -eq 0 ]; then
        "$SELF_DIR/profilectl.sh" balanced >/dev/null 2>&1 || :
        throttled=1
        printf '%s\n' "$temp" | jm_atomic_write "$STATE_DIR/thermal-throttled"
        jm_log thermal "throttled temperature_c=$temp"
    elif [ "$temp" -le "$THERMAL_RECOVER_C" ] && [ "$throttled" -eq 1 ]; then
        rm -f "$STATE_DIR/thermal-throttled"
        throttled=0
        jm_log thermal "recovered temperature_c=$temp"
    fi
    sleep "$THERMAL_POLL_SECONDS"
done
