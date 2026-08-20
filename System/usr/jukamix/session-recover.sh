#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

journal="$STATE_DIR/current-session"
lock="$STATE_DIR/game-session.lock"

if [ -r "$lock/pid" ]; then
    pid=$(cat "$lock/pid" 2>/dev/null || :)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        printf 'Session process %s is still active; refusing recovery.\n' "$pid" >&2
        exit 1
    fi
fi

"$SELF_DIR/profilectl.sh" restore >/dev/null 2>&1 || :
rm -rf "$lock"
if [ -f "$journal" ]; then
    mv "$journal" "$STATE_DIR/recovered-session.$(date +%s 2>/dev/null || printf unknown)"
fi
jm_log recovery "cleared stale session and restored profile"
printf 'Recovery completed.\n'
