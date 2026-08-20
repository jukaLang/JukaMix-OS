#!/bin/sh
set -eu
ROOT=${JUKAMIX_ROOT:-/mnt/SDCARD}
MANIFEST="$ROOT/System/var/jukamix/install-manifest-v5.txt"
[ -f "$MANIFEST" ] || { echo "v5 install manifest not found" >&2; exit 1; }

# Remove only files recorded by this pack. User state, logs, snapshots, and config remain.
while IFS= read -r path; do
    case $path in "$ROOT"/System/usr/jukamix/*) rm -f -- "$path";; esac
done < "$MANIFEST"
rm -f "$MANIFEST"
echo "Removed v5 program files; configuration and user state were preserved."
