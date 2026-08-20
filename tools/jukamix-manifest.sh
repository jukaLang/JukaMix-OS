#!/bin/sh
# JukaMix OS - verified manifest tool.
#
# Generates a SHA-256 manifest of JukaMix-owned system files, verifies a live
# installation against it, and repairs mismatched/missing owned files from a
# verified source tree (typically an update package).
#
# The "owned" scope is the System tree only. ROMs, BIOS files, saves and all
# other user data live OUTSIDE this tree and are never listed, verified, or
# touched by repair.
#
# Usage:
#   jukamix-manifest.sh --generate [--output FILE] [--root DIR]
#   jukamix-manifest.sh --verify   [--manifest FILE]
#   jukamix-manifest.sh --repair   --source DIR [--manifest FILE] [--dry-run]
# Exit code: 0 = ok, 1 = issues found, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

MODE=""
OUTPUT=""
MANIFEST=""
SOURCE=""
DRY_RUN=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0
OWNED_ROOT="${JUKAMIX_SYSTEM:-/mnt/SDCARD/System}"

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,22p' "$0"; exit 0 ;;
		--generate) MODE=generate ;;
		--verify)   MODE=verify ;;
		--repair)   MODE=repair ;;
		--output)   OUTPUT="$2"; shift ;;
		--manifest) MANIFEST="$2"; shift ;;
		--source)   SOURCE="$2"; shift ;;
		--root)     OWNED_ROOT="$2"; shift ;;
		--dry-run)  DRY_RUN=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

[ -n "$MANIFEST" ] || MANIFEST="$JUKAMIX_SUPPORT/jukamix-manifest.txt"

have_sha=0
jukamix_have_cmd sha256sum && have_sha=1

# List owned files (System tree, excluding logs/tmp).
owned_files() {
	_findroot="$1"
	[ -d "$_findroot" ] || return 0
	if jukamix_have_cmd find; then
		find "$_findroot" -type f \
			-not -path '*/logs/*' -not -path '*/.git/*' \
			-not -name '*.tmp' 2>/dev/null
	else
		# minimal fallback: no recursion guarantee, but harmless
		ls -1 "$_findroot" 2>/dev/null
	fi
	unset _findroot
}

do_generate() {
	[ -n "$OUTPUT" ] || OUTPUT="$MANIFEST"
	mkdir -p "${OUTPUT%/*}" 2>/dev/null
	: >"$OUTPUT"
	owned_files "$OWNED_ROOT" | while IFS= read -r _f; do
		[ -f "$_f" ] || continue
		if [ "$have_sha" = "1" ]; then
			_h=$(sha256sum "$_f" 2>/dev/null | cut -d' ' -f1)
		else
			_h=""
		fi
		_s=$(jukamix_filesize "$_f" 2>/dev/null)
		printf '%s|%s|%s\n' "$_f" "$_h" "$_s" >>"$OUTPUT"
	done
	# The loop above runs in a pipeline subshell, so count from the output file.
	_n=$(wc -l < "$OUTPUT" 2>/dev/null || printf '0')
	jukamix_log INFO "manifest written: $OUTPUT ($_n files)"
	[ "$JUKAMIX_QUIET" != "1" ] && printf 'Manifest: %s (%s files)\n' "$OUTPUT" "$_n" >&2
}

do_verify() {
	[ -f "$MANIFEST" ] || { jukamix_log ERROR "manifest not found: $MANIFEST"; exit 1; }
	_bad=0; _ok=0
	while IFS='|' read -r _f _h _s; do
		case "$_f" in \#*|"") continue ;; esac
		if [ ! -f "$_f" ]; then
			jukamix_log WARN "MISSING: $_f"; _bad=$((_bad+1)); continue
		fi
		if [ "$have_sha" = "1" ] && [ -n "$_h" ]; then
			_ch=$(sha256sum "$_f" 2>/dev/null | cut -d' ' -f1)
			if [ "$_ch" != "$_h" ]; then jukamix_log WARN "MODIFIED: $_f"; _bad=$((_bad+1)); continue; fi
		fi
		_ok=$((_ok+1))
	done < "$MANIFEST"
	jukamix_log INFO "verify complete: $_ok ok, $_bad issues"
	[ "$_bad" -gt 0 ] && exit 1
	exit 0
}

do_repair() {
	[ -d "$SOURCE" ] || { jukamix_log ERROR "source tree required for repair: $SOURCE"; exit 2; }
	[ -f "$MANIFEST" ] || { jukamix_log ERROR "manifest required for repair: $MANIFEST"; exit 2; }
	_fixed=0; _skip=0
	while IFS='|' read -r _f _h _s; do
		case "$_f" in \#*|"") continue ;; esac
		_rel=${_f#"$OWNED_ROOT"/}
		_src="$SOURCE/$_rel"
		[ -f "$_src" ] || { _skip=$((_skip+1)); continue; }
		_need=0
		if [ ! -f "$_f" ]; then _need=1
		elif [ "$have_sha" = "1" ] && [ -n "$_h" ]; then
			_ch=$(sha256sum "$_f" 2>/dev/null | cut -d' ' -f1)
			[ "$_ch" != "$_h" ] && _need=1
		fi
		if [ "$_need" = "1" ]; then
			if [ "$DRY_RUN" = "1" ]; then
				jukamix_log INFO "[dry-run] would repair: $_f"
			else
				jukamix_backup_file "$_f" 2>/dev/null
				mkdir -p "${_f%/*}" 2>/dev/null
				cp -p "$_src" "$_f" 2>/dev/null && jukamix_log INFO "repaired: $_f"
			fi
			_fixed=$((_fixed+1))
		fi
	done < "$MANIFEST"
	jukamix_log INFO "repair complete: $_fixed repaired, $_skip skipped (no source)"
	[ "$JUKAMIX_QUIET" != "1" ] && printf 'Repair: %s files, %s skipped\n' "$_fixed" "$_skip" >&2
}

case "$MODE" in
	generate) do_generate ;;
	verify)   do_verify ;;
	repair)   do_repair ;;
	*) jukamix_log ERROR "no mode specified (--generate|--verify|--repair)"; exit 2 ;;
esac
