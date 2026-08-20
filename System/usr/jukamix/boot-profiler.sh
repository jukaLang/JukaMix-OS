#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

event=${1:-checkpoint}
name=${2:-unnamed}
now=$(date +%s 2>/dev/null || printf 0)
uptime_s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || printf 0)
printf '%s\tevent=%s\tname=%s\tuptime=%s\n' "$now" "$event" "$name" "$uptime_s" \
    >> "$LOG_DIR/boot-profile.tsv"
