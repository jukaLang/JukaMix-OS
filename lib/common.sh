#!/bin/sh
set -u

JM_ROOT=${JUKAMIX_ROOT:-/mnt/SDCARD}
JM_PREFIX=${JM_PREFIX:-"$JM_ROOT/System/usr/jukamix"}
JM_ETC=${JM_ETC:-"$JM_ROOT/System/etc/jukamix"}
JM_VAR=${JM_VAR:-"$JM_ROOT/System/var/jukamix"}
JM_LOG=${JM_LOG:-"$JM_VAR/log"}
JM_RUN=${JM_RUN:-"$JM_VAR/run"}
JM_STATE=${JM_STATE:-"$JM_VAR/state"}
JM_CONFIG=${JM_CONFIG:-"$JM_ETC/jukamix.conf"}

jm_init_dirs() {
    umask 077
    mkdir -p "$JM_LOG" "$JM_RUN" "$JM_STATE" "$JM_VAR/notifications"
}

jm_now() { date '+%Y-%m-%dT%H:%M:%S%z'; }
jm_epoch() { date '+%s'; }

jm_log() {
    level=$1
    shift
    # Create dirs only once; after the first call the log dir already exists.
    [ -d "$JM_LOG" ] || jm_init_dirs
    printf '%s\t%s\t%s\n' "$(jm_now)" "$level" "$*" >> "$JM_LOG/jukamix.log"
}

jm_is_uint() {
    case ${1:-} in ''|*[!0-9]*) return 1;; *) return 0;; esac
}

jm_config_get() {
    key=$1
    default=${2:-}
    [ -f "$JM_CONFIG" ] || { printf '%s\n' "$default"; return; }
    # Single awk pass (was sed|tail): last match wins, values may contain '='.
    awk -v k="$key=" -v d="$default" '
        index($0, k) == 1 { v = substr($0, length(k) + 1) }
        END { if (v != "") print v; else print d }
    ' "$JM_CONFIG"
}

jm_atomic_write() {
    target=$1
    dir=$(dirname "$target")
    mkdir -p "$dir"
    tmp="$dir/.jm.$$.tmp"
    trap 'rm -f "$tmp"' EXIT HUP INT TERM
    cat > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$target"
    trap - EXIT HUP INT TERM
}

jm_lock_acquire() {
    name=$1
    stale=${2:-$(jm_config_get lock_stale_seconds 21600)}
    lock="$JM_RUN/$name.lock"
    jm_init_dirs
    if mkdir "$lock" 2>/dev/null; then
        printf '%s\n' "$$" > "$lock/pid"
        printf '%s\n' "$(jm_epoch)" > "$lock/time"
        return 0
    fi

    old_pid=$(cat "$lock/pid" 2>/dev/null || printf '')
    old_time=$(cat "$lock/time" 2>/dev/null || printf '0')
    now=$(jm_epoch)
    age=0
    jm_is_uint "$old_time" && age=$((now - old_time))

    # A lock whose owner is still alive is busy, regardless of age.
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        return 1
    fi
    # No pid recorded: the previous owner died before writing it (we write
    # pid+time within microseconds of mkdir). Reclaim an empty lock once it is
    # more than a second old instead of letting it block forever.
    if [ -z "$old_pid" ]; then
        [ "$age" -gt 1 ] || return 1
        rm -rf "$lock"
        mkdir "$lock" 2>/dev/null || return 1
        printf '%s\n' "$$" > "$lock/pid"
        printf '%s\n' "$now" > "$lock/time"
        return 0
    fi
    # Owner gone: reclaim only after the stale window (immediately when 0).
    if ! jm_is_uint "$stale" || [ "$age" -lt "$stale" ]; then
        return 1
    fi

    rm -rf "$lock"
    mkdir "$lock" 2>/dev/null || return 1
    printf '%s\n' "$$" > "$lock/pid"
    printf '%s\n' "$now" > "$lock/time"
}

jm_lock_release() {
    rm -rf "$JM_RUN/$1.lock"
}

jm_safe_id() {
    printf '%s' "$1" | cksum | awk '{print $1}'
}

jm_read_first() {
    for path in "$@"; do
        if [ -r "$path" ]; then
            cat "$path"
            return 0
        fi
    done
    return 1
}

jm_emit() {
    event=$1
    shift
    hook_dir="$JM_ETC/hooks.d/$event.d"
    [ -d "$hook_dir" ] || return 0
    for hook in "$hook_dir"/*; do
        [ -f "$hook" ] && [ -x "$hook" ] || continue
        "$hook" "$@" >> "$JM_LOG/hooks.log" 2>&1 ||
            jm_log WARN "hook failed: $hook event=$event"
    done
}
