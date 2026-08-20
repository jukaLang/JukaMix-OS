#!/bin/sh
# JukaMix OS - backup utility.
#
# Creates a timestamped 7z archive of selected JukaMix OS data sets:
#   config : System/etc, System/usr/trimui/scripts, RetroArch/retroarch.cfg
#   saves  : Saves/
#   bios   : BIOS/
#   all    : all of the above
#
# Backups are additive (never destructive to live data). Use --dry-run to
# preview the archive contents. The integrity of the resulting archive is
# verified with 7zz's built-in test.
#
# Exit code: 0 = ok, 1 = failure, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

WHAT="all"
OUTPUT=""
DRY_RUN=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		--what) WHAT="$2"; shift ;;
		--output) OUTPUT="$2"; shift ;;
		--dry-run) DRY_RUN=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-backup"
jukamix_begin

if [ ! -x "$JUKAMIX_SEVENZ" ]; then
	jukamix_log ERROR "7zz not available at $JUKAMIX_SEVENZ"
	exit 1
fi

case "$WHAT" in
	config|saves|bios|all) ;;
	*) jukamix_log ERROR "unknown --what: $WHAT"; exit 2 ;;
esac

BACKUP_DIR="$JUKAMIX_SUPPORT/backups"
mkdir -p "$BACKUP_DIR" 2>/dev/null
[ -z "$OUTPUT" ] && OUTPUT="$BACKUP_DIR/jukamix-$WHAT-$(date +%Y%m%d-%H%M%S).7z"

# Build the file list.
LISTFILE=$(jukamix_mktempdir)/list.txt
mkdir -p "${LISTFILE%/*}" 2>/dev/null
: >"$LISTFILE"

add_if_exists() {
	[ -e "$1" ] && echo "$1" >>"$LISTFILE"
}
case "$WHAT" in
	config|all)
		add_if_exists "$JUKAMIX_ETC"
		add_if_exists "$JUKAMIX_SCRIPTS"
		add_if_exists "$JUKAMIX_RETROARCH/retroarch.cfg"
		add_if_exists "$JUKAMIX_RA_HOME/config"
		;;
	saves|all) add_if_exists "$JUKAMIX_SAVES" ;;
	bios|all)  add_if_exists "$JUKAMIX_BIOS" ;;
esac

if [ ! -s "$LISTFILE" ]; then
	jukamix_log WARN "nothing to back up for --what=$WHAT"
	rm -rf "${LISTFILE%/*}" 2>/dev/null
	exit 0
fi

jukamix_log INFO "backing up ($WHAT) to $OUTPUT"
if [ "$DRY_RUN" = "1" ]; then
	jukamix_log INFO "[dry-run] would archive the following:"
	cat "$LISTFILE" >&2
	rm -rf "${LISTFILE%/*}" 2>/dev/null
	exit 0
fi

if "$JUKAMIX_SEVENZ" a -t7z -mx=1 "$OUTPUT" @"$LISTFILE" >/dev/null 2>&1; then
	jukamix_log INFO "archive created: $OUTPUT"
else
	jukamix_log ERROR "archive creation failed"
	rm -rf "${LISTFILE%/*}" 2>/dev/null
	exit 1
fi

# Verify integrity.
if "$JUKAMIX_SEVENZ" t "$OUTPUT" >/dev/null 2>&1; then
	jukamix_log INFO "archive integrity verified"
else
	jukamix_log ERROR "archive integrity check failed"
	rm -rf "${LISTFILE%/*}" 2>/dev/null
	exit 1
fi

rm -rf "${LISTFILE%/*}" 2>/dev/null
exit 0
