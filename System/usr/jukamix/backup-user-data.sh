#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

root=$(jm_root)
stamp=$(date '+%Y%m%d-%H%M%S' 2>/dev/null || printf unknown)
destination="$BACKUP_DIR/$stamp"
mkdir -p "$destination"

# Deliberately excludes ROM and BIOS content. Add project-specific config paths here.
paths="
System/etc
System/var/jukamix
RetroArch/.retroarch/config
Emus
Themes
"

manifest="$destination/MANIFEST.txt"
: > "$manifest"

for relative in $paths; do
    source="$root/$relative"
    [ -e "$source" ] || continue
    archive_name=$(printf '%s' "$relative" | tr '/' '_')
    archive="$destination/$archive_name.tar.gz"
    tar -czf "$archive" -C "$root" "$relative" || {
        rm -f "$archive"
        jm_log backup "failed path=$relative"
        continue
    }
    jm_sha256 "$archive" >> "$manifest"
done

printf 'created=%s\nroot=%s\n' "$stamp" "$root" >> "$manifest"
jm_log backup "created destination=$destination"
printf 'Backup created: %s\n' "$destination"
