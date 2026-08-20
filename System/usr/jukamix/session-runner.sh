#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

profile=$DEFAULT_PROFILE
if [ "${1:-}" = "--profile" ]; then
    profile=${2:-}
    shift 2
fi

[ "$#" -gt 0 ] || {
    printf 'Usage: %s [--profile NAME] COMMAND [ARG...]\n' "$0" >&2
    exit 2
}

"$SELF_DIR/storage-guard.sh" "$(jm_root)" || exit 1

lock="$STATE_DIR/game-session.lock"
jm_lock "$lock" || {
    printf 'Another game session is active. Run recovery if it crashed.\n' >&2
    exit 1
}

started=$(date +%s 2>/dev/null || printf 0)
command_text=$(printf '%s ' "$@")
journal="$STATE_DIR/current-session"

cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM
    "$SELF_DIR/profilectl.sh" restore >/dev/null 2>&1 || :
    ended=$(date +%s 2>/dev/null || printf 0)
    duration=$((ended - started))
    {
        printf 'status=finished\n'
        printf 'exit_code=%s\n' "$rc"
        printf 'duration_seconds=%s\n' "$duration"
        printf 'command=%s\n' "$command_text"
    } | jm_atomic_write "$STATE_DIR/last-session"
    rm -f "$journal"
    jm_unlock "$lock"
    jm_log session "finished rc=$rc duration=$duration command=$command_text"
    exit "$rc"
}
trap cleanup EXIT HUP INT TERM

{
    printf 'status=running\n'
    printf 'pid=%s\n' "$$"
    printf 'started=%s\n' "$started"
    printf 'profile=%s\n' "$profile"
    printf 'command=%s\n' "$command_text"
} | jm_atomic_write "$journal"

"$SELF_DIR/profilectl.sh" "$profile" || exit 1
jm_log session "started profile=$profile command=$command_text"
"$@"
