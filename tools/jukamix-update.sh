#!/bin/sh
# JukaMix OS - offline update verifier (validation only).
#
# This tool DOES NOT download firmware, apply updates, or flash the device.
# There is intentionally no network or signing infrastructure here.
#
# It validates a LOCAL update package (a directory or archive) by:
#   1. Reading an optional update-manifest.json (checksums, min_version,
#      target_device) when jq is available.
#   2. Verifying file checksums if present in the manifest.
#   3. Checking device capability against tools/data/device-capabilities.txt.
#   4. Comparing the package's minimum required version to the running one.
# It then reports whether the package appears applicable to THIS device.
#
# Exit code: 0 = applicable, 1 = not applicable / failed validation, 2 = usage.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

PACKAGE=""
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		--package) PACKAGE="$2"; shift ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

if [ -z "$PACKAGE" ]; then
	jukamix_log ERROR "provide --package <dir-or-archive>"
	exit 2
fi
if [ ! -e "$PACKAGE" ]; then
	jukamix_log ERROR "package not found: $PACKAGE"
	exit 2
fi

jukamix_init_log "jukamix-update"
jukamix_begin

APPLICABLE=1   # 1 = yes, 0 = no
NOTES=""

# Resolve to a directory (extract archives to temp if needed).
PKGDIR="$PACKAGE"
CLEANUP_TMP=""
if [ -f "$PACKAGE" ]; then
	if [ ! -x "$JUKAMIX_SEVENZ" ]; then
		jukamix_log ERROR "package is an archive but 7zz is unavailable"
		exit 1
	fi
	_t=$(jukamix_mktempdir) || { jukamix_log ERROR "cannot make temp"; exit 1; }
	jukamix_trap_cleanup; JUKAMIX_TMPDIR="$_t"
	"$JUKAMIX_SEVENZ" x -y "-o$_t" "$PACKAGE" >/dev/null 2>&1 || { jukamix_log ERROR "cannot extract package"; exit 1; }
	PKGDIR="$_t"
	CLEANUP_TMP=1
fi

# Locate manifest.
MANIFEST=""
for _c in "$PKGDIR/update-manifest.json" "$PKGDIR/manifest.json" "$PKGDIR/update-manifest.txt"; do
	[ -f "$_c" ] && MANIFEST="$_c" && break
done

MIN_VER=""; TARGET_DEV=""
if [ -n "$MANIFEST" ] && [ -x "$JUKAMIX_JQ" ]; then
	MIN_VER=$("$JUKAMIX_JQ" -r '.min_version // empty' "$MANIFEST" 2>/dev/null)
	TARGET_DEV=$("$JUKAMIX_JQ" -r '.target_device // empty' "$MANIFEST" 2>/dev/null)
	jukamix_log INFO "manifest: min_version=$MIN_VER target_device=$TARGET_DEV"
elif [ -n "$MANIFEST" ]; then
	jukamix_log WARN "manifest found but jq unavailable; skipping structured checks"
fi

# Device capability check.
CAPOK=0
if [ "$JUKAMIX_DEVICE" != "UNKNOWN" ]; then
	while IFS='|' read -r _code _name _arch _fwmin _notes; do
		case "$_code" in \#*|"") continue ;; esac
		if [ "$_code" = "$JUKAMIX_DEVICE" ]; then CAPOK=1; break; fi
	done <"$TOOLS_DIR/data/device-capabilities.txt"
	if [ "$CAPOK" = "0" ]; then
		APPLICABLE=0; NOTES="$NOTES device '$JUKAMIX_DEVICE' not in capability list;"
	fi
else
	jukamix_log WARN "device unknown (off-device run); cannot assert capability"
fi

# Version gate.
if [ -n "$MIN_VER" ] && [ "$JUKAMIX_VERSION" != "UNKNOWN" ]; then
	_req=$(echo "$MIN_VER" | tr -d 'vV')
	_cur=$(echo "$JUKAMIX_VERSION" | tr -d 'vV')
	_latest=$(printf '%s\n%s\n' "$_req" "$_cur" | sort -t. -k1,1 -k2,2 -k3,3 -n | tail -n1)
	if [ "$_latest" != "$_cur" ]; then
		APPLICABLE=0; NOTES="$NOTES requires JukaMix OS >= $MIN_VER (have $JUKAMIX_VERSION);"
	fi
fi

# Checksum verification (if manifest lists files/sha256).
# Extract name+sha256 with a single jq pass (was two jq forks per file), then
# verify in a plain (non-pipeline) while loop so APPLICABLE/NOTES persist.
if [ -n "$MANIFEST" ] && [ -x "$JUKAMIX_JQ" ] && jukamix_have_cmd sha256sum; then
	_jlist="$JUKAMIX_TMPBASE/.$JUKAMIX_PREFIX-files-$$.tmp"
	"$JUKAMIX_JQ" -r '.files[]? | (.name // "") + "\t" + (.sha256 // "")' "$MANIFEST" >"$_jlist" 2>/dev/null
	while IFS='\t' read -r _f _h; do
		[ -z "$_f" ] && continue
		if [ -f "$PKGDIR/$_f" ]; then
			_got=$(sha256sum "$PKGDIR/$_f" | cut -c1-64)
			if [ "$_got" != "$_h" ]; then
				APPLICABLE=0; NOTES="$NOTES checksum mismatch for $_f;"
			fi
		else
			APPLICABLE=0; NOTES="$NOTES missing file $_f;"
		fi
	done <"$_jlist"
	rm -f "$_jlist" 2>/dev/null
fi

if [ "$CLEANUP_TMP" = "1" ]; then
	rm -rf "$PKGDIR" 2>/dev/null
fi

if [ "$APPLICABLE" = "1" ]; then
	jukamix_log INFO "RESULT: package appears APPLICABLE to this device."
	[ -n "$NOTES" ] && jukamix_log INFO "notes: $NOTES"
	exit 0
else
	jukamix_log INFO "RESULT: package NOT applicable / failed validation."
	jukamix_log INFO "reasons: $NOTES"
	jukamix_log INFO "NOTE: this tool cannot install or flash updates (offline verifier only)."
	exit 1
fi
