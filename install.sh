#!/bin/sh
set -eu
ROOT=${JUKAMIX_ROOT:-/mnt/SDCARD}
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREFIX="$ROOT/System/usr/jukamix"
ETC="$ROOT/System/etc/jukamix"
VAR="$ROOT/System/var/jukamix"
MANIFEST="$VAR/install-manifest-v5.txt"

copy_file() {
    rel=$1
    src="$SRC/$rel"
    case $rel in
        bin/*|lib/*|migrations/*) dest="$PREFIX/$rel";;
        config/jukamix.conf) dest="$ETC/jukamix.conf";;
        *) return 0;;
    esac
    if [ "$DRY" -eq 1 ]; then printf 'COPY %s -> %s\n' "$rel" "$dest"; return; fi
    mkdir -p "$(dirname "$dest")"
    if [ "$rel" = config/jukamix.conf ] && [ -f "$dest" ]; then
        printf 'KEEP %s\n' "$dest"
        return
    fi
    cp -p "$src" "$dest"
    printf '%s\n' "$dest" >> "$MANIFEST.tmp"
}

if [ "$DRY" -eq 0 ]; then
    umask 077
    mkdir -p "$PREFIX" "$ETC" "$VAR/log" "$VAR/run" "$VAR/state" "$VAR/notifications"
    : > "$MANIFEST.tmp"
fi

find "$SRC/bin" "$SRC/lib" "$SRC/migrations" -type f | while IFS= read -r path; do
    copy_file "${path#"$SRC/"}"
done
copy_file config/jukamix.conf

if [ "$DRY" -eq 0 ]; then
    sort -u "$MANIFEST.tmp" > "$MANIFEST"
    rm -f "$MANIFEST.tmp"
    chmod 700 "$PREFIX/bin/"* "$PREFIX/migrations/"*.sh
    JUKAMIX_ROOT="$ROOT" "$PREFIX/bin/jm-migrate"
    JUKAMIX_ROOT="$ROOT" "$PREFIX/bin/jm-doctor" --quiet
    # Prepare PortMaster entry points (Data/ports + PORTS-tab launcher).
    if [ -x "$PREFIX/bin/jm-portmaster" ]; then
        JUKAMIX_ROOT="$ROOT" "$PREFIX/bin/jm-portmaster" fix >/dev/null 2>&1 || true
    fi
    printf 'Installed JukaMix optimization pack v5 in %s\n' "$ROOT"
fi
