#!/bin/sh
# JukaMix OS - BIOS checker (privacy-safe).
#
# Cross-references the BIOS directory against the repository manifest
# (tools/data/bios-manifest.txt). It reports presence, missing, optional extras,
# and (when the manifest supplies them) size and hash verification. It never
# prints BIOS file contents or ROM names from user data.
#
# Default mode is read-only. Use --copy-from <src> to populate missing
# manifest entries from a user-supplied source (creates backups first).
# Exit code: 0 = ok, 1 = issues, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

MANIFEST="$TOOLS_DIR/data/bios-manifest.txt"
COPY_FROM=""
JSON=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		--manifest) MANIFEST="$2"; shift ;;
		--copy-from) COPY_FROM="$2"; shift ;;
		--json) JSON=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-bios-check"
jukamix_begin

if [ ! -f "$MANIFEST" ]; then
	jukamix_log ERROR "manifest not found: $MANIFEST"
	exit 2
fi
[ -d "$JUKAMIX_BIOS" ] || mkdir -p "$JUKAMIX_BIOS" 2>/dev/null

PRESENT=0; MISSING=0; EXTRA=0; BAD=0

out() {
	if [ "$JSON" = "1" ]; then printf '%s\n' "$1"; else printf '%s\n' "$1" >&2; fi
}

# Build a set of manifest filenames for "extra" detection.
while IFS='|' read -r _sys _fn _region _class _min _max _ha _hash _notes; do
	case "$_sys" in \#*|"") continue ;; esac
	[ -z "$_fn" ] && continue
	_mf_seen="${_mf_seen:-} $_fn"

	if [ -f "$JUKAMIX_BIOS/$_fn" ]; then
		PRESENT=$((PRESENT+1))
		# size check
		if [ "${_min:-0}" != "0" ] && [ "${_max:-0}" != "0" ]; then
			_sz=$(jukamix_filesize "$JUKAMIX_BIOS/$_fn")
			if [ "$_sz" -lt "$_min" ] || [ "$_sz" -gt "$_max" ]; then
				out "[WARN] $_fn size $_sz out of expected [$_min,$_max]"
				BAD=$((BAD+1))
			fi
		fi
		# hash check
		if [ -n "$_hash" ]; then
			case "$_ha" in
				sha256)
					if jukamix_have_cmd sha256sum; then
						_got=$(sha256sum "$JUKAMIX_BIOS/$_fn" | cut -c1-64)
						if [ "$_got" != "$_hash" ]; then out "[FAIL] $_fn hash mismatch"; BAD=$((BAD+1)); fi
					fi ;;
				md5)
					if jukamix_have_cmd md5sum; then
						_got=$(md5sum "$JUKAMIX_BIOS/$_fn" | cut -c1-32)
						if [ "$_got" != "$_hash" ]; then out "[FAIL] $_fn hash mismatch"; BAD=$((BAD+1)); fi
					fi ;;
			esac
		fi
		out "[OK]   $_fn ($_class)"
	else
		case "$_class" in
			required) out "[MISS] $_fn (required)"; MISSING=$((MISSING+1)) ;;
			recommended) out "[MISS] $_fn (recommended)"; MISSING=$((MISSING+1)) ;;
			*) out "[opt]  $_fn (optional, missing)" ;;
		esac
	fi
done <"$MANIFEST"

# Extra files (not in manifest) - report names only, not contents.
# _mf_seen is a space-separated set; a case match is a pure builtin, replacing
# the previous per-file loop over every manifest name.
for _f in "$JUKAMIX_BIOS"/*; do
	[ -f "$_f" ] || continue
	_base=${_f##*/}
	case " $_mf_seen " in
		*" $_base "*) ;;
		*) out "[ext]  $_base (not in manifest)"; EXTRA=$((EXTRA+1)) ;;
	esac
done

out "---- BIOS summary: present=$PRESENT missing=$MISSING extra=$EXTRA bad=$BAD ----"

# Optional population from a user-supplied source.
if [ -n "$COPY_FROM" ]; then
	if [ ! -d "$COPY_FROM" ]; then
		jukamix_log ERROR "copy source not a directory: $COPY_FROM"
		exit 2
	fi
	jukamix_log INFO "populating missing manifest BIOS from $COPY_FROM (backups created)"
	while IFS='|' read -r _sys _fn _region _class _min _max _ha _hash _notes; do
		case "$_sys" in \#*|"") continue ;; esac
		[ -z "$_fn" ] && continue
		if [ ! -f "$JUKAMIX_BIOS/$_fn" ] && [ -f "$COPY_FROM/$_fn" ]; then
			jukamix_backup_file "$JUKAMIX_BIOS/$_fn" >/dev/null 2>&1
			cp "$COPY_FROM/$_fn" "$JUKAMIX_BIOS/$_fn" 2>/dev/null \
				&& jukamix_log INFO "copied $_fn" || jukamix_log ERROR "failed to copy $_fn"
		fi
	done <"$MANIFEST"
fi

if [ "$MISSING" -gt 0 ] || [ "$BAD" -gt 0 ]; then
	exit 1
fi
exit 0
