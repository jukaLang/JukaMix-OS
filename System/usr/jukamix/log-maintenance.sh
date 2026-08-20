#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

for log in "$LOG_DIR"/*.log; do
    [ -f "$log" ] || continue
    size_kb=$(du -k "$log" 2>/dev/null | awk '{print $1}')
    size_kb=${size_kb:-0}
    [ "$size_kb" -lt "$MAX_LOG_KB" ] && continue
    i=$MAX_LOG_FILES
    while [ "$i" -gt 1 ]; do
        previous=$((i - 1))
        [ -f "$log.$previous" ] && mv -f "$log.$previous" "$log.$i"
        i=$previous
    done
    mv -f "$log" "$log.1"
    : > "$log"
done

find "$CACHE_DIR" -type f -mtime +"$CACHE_MAX_AGE_DAYS" -delete 2>/dev/null || :
jm_log maintenance "log rotation and cache cleanup complete"
