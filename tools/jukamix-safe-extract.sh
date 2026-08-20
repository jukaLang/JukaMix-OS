#!/bin/sh
# JukaMix OS - safe archive extractor.
#
# Wraps 7zz to extract archives to an isolated temporary directory, validates
# the result for path-traversal and symlink/hardlink escapes, and only then
# (with --apply) atomically moves the contents into the destination. By default
# it only lists/validates (--check). Destructive application requires --apply
# and always creates backups of any overwritten files.
#
# Exit code: 0 = ok, 1 = validation/extract failure, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

ARCHIVE=""
DEST=""
CHECK_ONLY=1
DRY_RUN=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		--archive) ARCHIVE="$2"; shift ;;
		--dest) DEST="$2"; shift ;;
		--check) CHECK_ONLY=1 ;;
		--apply) CHECK_ONLY=0 ;;
		--dry-run) DRY_RUN=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
	jukamix_log ERROR "provide a valid --archive <file>"
	exit 2
fi
if [ "$CHECK_ONLY" = "0" ] && [ -z "$DEST" ]; then
	jukamix_log ERROR "--apply requires --dest <dir>"
	exit 2
fi

jukamix_init_log "jukamix-safe-extract"
jukamix_begin

if [ ! -x "$JUKAMIX_SEVENZ" ]; then
	jukamix_log ERROR "7zz not available at $JUKAMIX_SEVENZ"
	exit 1
fi

WORK=$(jukamix_mktempdir) || { jukamix_log ERROR "cannot create temp dir"; exit 1; }
jukamix_trap_cleanup
JUKAMIX_TMPDIR="$WORK"

jukamix_log INFO "extracting ${ARCHIVE##*/} to $WORK"
if ! "$JUKAMIX_SEVENZ" x -y "-o$WORK" "$ARCHIVE" >/dev/null 2>&1; then
	jukamix_log ERROR "extraction failed"
	rm -rf "$WORK" 2>/dev/null
	exit 1
fi

# Validation: reject absolute paths, '..' traversal, and symlink/hardlink escapes.
BAD=0
while IFS= read -r _p; do
	case "$_p" in
		/*) jukamix_log WARN "absolute path in archive: $_p"; BAD=$((BAD+1)) ;;
		*/../*|*/..|../*) jukamix_log WARN "traversal in archive: $_p"; BAD=$((BAD+1)) ;;
	esac
	# symlink/hardlink escape check
	if [ -L "$WORK/$_p" ] || [ -e "$WORK/$_p" ] && jukamix_have_cmd readlink; then
		_rl=$(readlink -m "$WORK/$_p" 2>/dev/null || true)
		case "$_rl" in
			"$WORK"*) ;;
			*) jukamix_log WARN "link escapes sandbox: $_p -> $_rl"; BAD=$((BAD+1)) ;;
		esac
	fi
done <<EOF
$(cd "$WORK" && find . -mindepth 1 | sed 's|^\./||')
EOF

if [ "$BAD" -gt 0 ]; then
	jukamix_log ERROR "archive failed validation ($BAD issue(s)); not applying"
	rm -rf "$WORK" 2>/dev/null
	exit 1
fi

jukamix_log INFO "archive validated (no traversal/escape issues)"
if [ "$JUKAMIX_QUIET" != "1" ]; then
	echo "Contents:" >&2
	(cd "$WORK" && find . -mindepth 1 | sed 's|^\./|  |' >&2)
fi

if [ "$CHECK_ONLY" = "1" ]; then
	jukamix_log INFO "check-only mode; extracted tree left at $WORK for inspection"
	exit 0
fi

# Apply
if [ "$DRY_RUN" = "1" ]; then
	jukamix_log INFO "[dry-run] would move $WORK/* -> $DEST"
	rm -rf "$WORK" 2>/dev/null
	exit 0
fi

mkdir -p "$DEST" 2>/dev/null
# Create every archive directory once (instead of one mkdir per file), which
# also preserves empty directories from the archive.
(cd "$WORK" && find . -mindepth 1 -type d) | while IFS= read -r _d; do
	mkdir -p "$DEST/$_d" 2>/dev/null
done
# Backup any files that will be overwritten.
jukamix_log INFO "applying to $DEST (backups retained)"
(cd "$WORK" && find . -mindepth 1 -type f) | while IFS= read -r _f; do
	_destf="$DEST/$_f"
	if [ -f "$_destf" ]; then
		jukamix_backup_file "$_destf" >/dev/null 2>&1
	fi
	mv -f "$WORK/$_f" "$_destf" 2>/dev/null || jukamix_log WARN "failed to move $_f"
done

rm -rf "$WORK" 2>/dev/null
jukamix_log INFO "apply complete"
exit 0
