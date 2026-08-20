#!/bin/sh

set -u

jm_root() {
    printf '%s\n' "${JUKAMIX_ROOT:-/mnt/SDCARD}"
}

jm_load_config() {
    root=$(jm_root)
    cfg=${JUKAMIX_CONFIG:-"$root/config/jukamix.conf"}
    [ -r "$cfg" ] || cfg="$root/System/usr/jukamix/config/jukamix.conf"
    [ -r "$cfg" ] && . "$cfg"
    : "${STATE_DIR:=System/var/jukamix}"
    : "${LOG_DIR:=System/var/log/jukamix}"
    : "${BACKUP_DIR:=Backups/JukaMix}"
    : "${CACHE_DIR:=System/cache/jukamix}"
    : "${MIN_FREE_MB:=256}"
    : "${MIN_FREE_INODES:=512}"
    : "${THERMAL_HOT_C:=78}"
    : "${THERMAL_RECOVER_C:=70}"
    : "${THERMAL_POLL_SECONDS:=5}"
    : "${MAX_LOG_KB:=512}"
    : "${MAX_LOG_FILES:=5}"
    : "${CACHE_MAX_AGE_DAYS:=14}"
    : "${DEFAULT_PROFILE:=balanced}"
    case "$STATE_DIR" in /*) :;; *) STATE_DIR="$root/$STATE_DIR";; esac
    case "$LOG_DIR" in /*) :;; *) LOG_DIR="$root/$LOG_DIR";; esac
    case "$BACKUP_DIR" in /*) :;; *) BACKUP_DIR="$root/$BACKUP_DIR";; esac
    case "$CACHE_DIR" in /*) :;; *) CACHE_DIR="$root/$CACHE_DIR";; esac
    export STATE_DIR LOG_DIR BACKUP_DIR CACHE_DIR
}

jm_init_dirs() {
    jm_load_config
    mkdir -p "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR" "$CACHE_DIR"
}

jm_log() {
    jm_init_dirs
    component=$1
    shift
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)
    printf '%s [%s] %s\n' "$timestamp" "$component" "$*" >> "$LOG_DIR/$component.log"
}

jm_atomic_write() {
    destination=$1
    directory=$(dirname "$destination")
    mkdir -p "$directory"
    temporary="$destination.tmp.$$"
    cat > "$temporary" || { rm -f "$temporary"; return 1; }
    sync "$temporary" 2>/dev/null || :
    mv -f "$temporary" "$destination"
}

jm_lock() {
    lockdir=$1
    if mkdir "$lockdir" 2>/dev/null; then
        printf '%s\n' "$$" > "$lockdir/pid"
        return 0
    fi
    if [ -r "$lockdir/pid" ]; then
        oldpid=$(cat "$lockdir/pid" 2>/dev/null || :)
        if [ -n "$oldpid" ] && ! kill -0 "$oldpid" 2>/dev/null; then
            rm -rf "$lockdir"
            mkdir "$lockdir" 2>/dev/null || return 1
            printf '%s\n' "$$" > "$lockdir/pid"
            return 0
        fi
    fi
    return 1
}

jm_unlock() {
    [ -n "${1:-}" ] && rm -rf "$1"
}

jm_read_int() {
    value=$(cat "$1" 2>/dev/null || printf '0')
    case "$value" in ''|*[!0-9-]*) printf '0\n';; *) printf '%s\n' "$value";; esac
}

jm_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1"
    elif command -v busybox >/dev/null 2>&1; then
        busybox sha256sum "$1"
    else
        printf 'UNAVAILABLE  %s\n' "$1"
    fi
}
