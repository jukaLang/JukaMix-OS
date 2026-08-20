#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

profile=${1:-status}
snapshot="$STATE_DIR/profile.snapshot"
lock="$STATE_DIR/profile.lock"

cpu_governors() {
    for p in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor \
             /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -e "$p" ] && printf '%s\n' "$p"
    done
}

save_snapshot() {
    [ -s "$snapshot" ] && return 0
    {
        cpu_governors | while IFS= read -r node; do
            printf '%s\t%s\n' "$node" "$(cat "$node" 2>/dev/null || :)"
        done
        for node in /sys/class/devfreq/*/governor; do
            [ -e "$node" ] &&
                printf '%s\t%s\n' "$node" "$(cat "$node" 2>/dev/null || :)"
        done
    } | jm_atomic_write "$snapshot"
}

write_node() {
    node=$1
    value=$2
    [ -w "$node" ] || return 0
    printf '%s' "$value" > "$node" 2>/dev/null || {
        jm_log profilectl "write_failed node=$node value=$value"
        return 0
    }
}

apply_governor() {
    governor=$1
    cpu_governors | while IFS= read -r node; do write_node "$node" "$governor"; done
}

apply_profile() {
    save_snapshot
    case "$1" in
        battery)
            apply_governor powersave
            ;;
        balanced)
            apply_governor schedutil
            ;;
        performance)
            apply_governor performance
            ;;
        maximum)
            apply_governor performance
            jm_log profilectl "maximum profile requested; no unsafe fixed clocks applied"
            ;;
        *)
            printf 'Unknown profile: %s\n' "$1" >&2
            return 2
            ;;
    esac
    printf '%s\n' "$1" | jm_atomic_write "$STATE_DIR/active-profile"
    jm_log profilectl "applied profile=$1"
}

restore_profile() {
    [ -r "$snapshot" ] || return 0
    while IFS="$(printf '\t')" read -r node value; do
        [ -n "$node" ] && [ -n "$value" ] && write_node "$node" "$value"
    done < "$snapshot"
    rm -f "$snapshot" "$STATE_DIR/active-profile"
    jm_log profilectl "restored previous hardware settings"
}

case "$profile" in
    restore)
        restore_profile
        ;;
    status)
        printf 'active=%s\n' "$(cat "$STATE_DIR/active-profile" 2>/dev/null || printf 'stock')"
        ;;
    battery|balanced|performance|maximum)
        jm_lock "$lock" || {
            printf 'Profile manager is busy.\n' >&2
            exit 1
        }
        trap 'jm_unlock "$lock"' EXIT HUP INT TERM
        apply_profile "$profile"
        ;;
    *)
        printf 'Usage: %s {battery|balanced|performance|maximum|restore|status}\n' "$0" >&2
        exit 2
        ;;
esac
