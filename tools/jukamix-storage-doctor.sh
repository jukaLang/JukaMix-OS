#!/bin/sh
# JukaMix OS - storage doctor (read-only).
#
# Reports free space per relevant mount point, surfaces unusually large files
# under user data areas (ROMs/Saves/BIOS) for triage, and flags low-space
# conditions. Never deletes or modifies data.
#
# Exit code: 0 = ok, 1 = warnings issued, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

TOP_N=10
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		--top) TOP_N="$2"; shift ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-storage-doctor"
jukamix_begin

if ! jukamix_have_cmd df; then
	jukamix_log ERROR "df not available; cannot report free space"
	exit 2
fi

echo "Storage overview:" >&2
for _p in "$JUKAMIX_ROOT" "$JUKAMIX_ROMS" "$JUKAMIX_SAVES" "$JUKAMIX_BIOS" "$JUKAMIX_PORTMASTER"; do
	[ -d "$_p" ] || { echo "  (missing) $_p" >&2; continue; }
	_mp=$(jukamix_mountpoint "$_p")
	_free=$(jukamix_free_space_mb "$_p")
	if [ "$_free" = "0" ] || [ -z "$_free" ]; then
		echo "  $_p : free space unknown" >&2
	else
		echo "  $_p : ${_free} MB free (mount $_mp)" >&2
		if [ "$_free" -lt 512 ]; then
			echo "    !! low free space (<512 MB)" >&2
		fi
	fi
done

echo "" >&2
echo "Largest files under user data (top $TOP_N each):" >&2
for _area in "$JUKAMIX_ROMS" "$JUKAMIX_SAVES" "$JUKAMIX_BIOS"; do
	[ -d "$_area" ] || continue
	echo "  == $_area ==" >&2
	if jukamix_have_cmd find && jukamix_have_cmd du; then
		find "$_area" -type f -exec du -k {} + 2>/dev/null | sort -rn | head -n "$TOP_N" | \
			while IFS= read -r _line; do
				_kb=$(echo "$_line" | cut -f1)
				_f=$(echo "$_line" | cut -f2-)
				echo "    $((_kb/1024)) MB  ${_f##*/}" >&2
			done
	else
		echo "    (find/du unavailable)" >&2
	fi
done

exit 0
