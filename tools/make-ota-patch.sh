#!/bin/sh
# JukaMix OS - incremental OTA patch generator.
#
# Diffs two OTA manifests (as produced by tools/make-ota-manifest.sh) and
# produces a minimal patch carrying only the files that changed between the
# two releases:
#   <out-dir>/manifest.txt   install/replace/remove operations
#   <out-dir>/patch.zip      payload containing only the changed files
#   <out-dir>/SHA256SUMS     checksum of patch.zip
#
# The patch manifest and zip are consumed directly by the on-device OTA engine
# (tools/lib/jukamix-ota.sh). Point a package's archive_url/manifest_url at
# these two artifacts and the device downloads just the delta instead of the
# full OS image - which is what makes updates fast/instantaneous.
#
# Usage:
#   make-ota-patch.sh <old-manifest.txt> <new-manifest.txt> <new-os-root> <out-dir> [dest-root]

set -u

OLD_MAN="${1:-}"
NEW_MAN="${2:-}"
OS_ROOT="${3:-}"
OUT="${4:-}"
DEST_ROOT="${5:-/mnt/SDCARD}"

usage() {
	echo "usage: make-ota-patch.sh <old-manifest> <new-manifest> <new-os-root> <out-dir> [dest-root]" >&2
	exit 2
}

[ -n "$OLD_MAN" ] && [ -n "$NEW_MAN" ] && [ -n "$OS_ROOT" ] && [ -n "$OUT" ] || usage
[ -f "$OLD_MAN" ] || { echo "old manifest not found: $OLD_MAN" >&2; exit 2; }
[ -f "$NEW_MAN" ] || { echo "new manifest not found: $NEW_MAN" >&2; exit 2; }
[ -d "$OS_ROOT" ] || { echo "not a directory: $OS_ROOT" >&2; exit 2; }

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$SCRIPT_DIR/lib/jukamix-update.sh" ]; then
	. "$SCRIPT_DIR/lib/jukamix-update.sh" 2>/dev/null
fi

# Host fallback in case the shared helper is unavailable.
if ! command -v jukamix_update_sha256 >/dev/null 2>&1; then
	jukamix_update_sha256() {
		if command -v sha256sum >/dev/null 2>&1; then
			sha256sum "$1" 2>/dev/null | awk '{print $1}'
		elif command -v openssl >/dev/null 2>&1; then
			openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
		fi
	}
fi

mkdir -p "$OUT"

OLD_IDX="${TMPDIR:-/tmp}/jukaix-ota-old-$$.idx"
NEW_IDX="${TMPDIR:-/tmp}/jukaix-ota-new-$$.idx"
trap 'rm -f "$OLD_IDX" "$NEW_IDX"' EXIT INT TERM

# Normalize each TAB-delimited manifest line
# ("<op>\t<rel>\t<dest>\t<sha>[\t<flag>]") into "rel|dest|sha|flag" for fast
# single-pass diffing. The pipe join is safe because OS paths never contain '|';
# the input delimiter is a TAB so paths with spaces survive.
normalize() {
	awk -F'\t' '{ print $2 "|" $3 "|" $4 "|" ($5 != "" ? $5 : "") }' "$1" | sort
}
normalize "$OLD_MAN" > "$OLD_IDX"
normalize "$NEW_MAN" > "$NEW_IDX"

: > "$OUT/manifest.txt"
: > "$OUT/files.txt"

# Pass 1: install (new) / replace (changed sha) and collect the changed paths.
awk -F'|' -v man="$OUT/manifest.txt" -v files="$OUT/files.txt" '
	NR==FNR { oldsha[$1] = $3; next }
	{
		rel = $1; dest = $2; sha = $3; flag = $4
		if (!(rel in oldsha)) op = "install"
		else if (oldsha[rel] != sha) op = "replace"
		else next
		line = op "\t" rel "\t" dest "\t" sha
		if (flag != "") line = line "\t" flag
		print line >> man
		print rel >> files
	}
' "$OLD_IDX" "$NEW_IDX"

# Pass 2: remove any file that existed in the old release but not the new one.
awk -F'|' -v man="$OUT/manifest.txt" '
	NR==FNR { new[$1] = 1; next }
	{ if (!($1 in new)) print "remove\t" $2 >> man }
' "$NEW_IDX" "$OLD_IDX"

# Build the payload zip from the changed paths, rooted at the OS tree root so
# the OTA applier can resolve each manifest entry under its payload dir.
if [ -s "$OUT/files.txt" ]; then
	if ! (
		cd "$OS_ROOT" || exit 1
		if command -v zip >/dev/null 2>&1; then
			zip -X -q -r "$OUT/patch.zip" -@ < "$OUT/files.txt"
		elif command -v 7zz >/dev/null 2>&1; then
			# @listfile keeps one path per line, so paths with spaces survive.
			7zz a -tzip -r "$OUT/patch.zip" @"$OUT/files.txt"
		else
			echo "error: zip or 7zz required to build the payload" >&2
			exit 1
		fi
	); then
		echo "error: failed to build patch.zip" >&2
		exit 1
	fi
else
	# Nothing changed between the two manifests: emit an empty patch.
	: > "$OUT/patch.zip"
fi

_hash=$(jukamix_update_sha256 "$OUT/patch.zip")
printf '%s  %s\n' "$_hash" "patch.zip" > "$OUT/SHA256SUMS"

printf 'patch: %s ops, %s payload files -> %s\n' \
	"$(wc -l < "$OUT/manifest.txt")" \
	"$(wc -l < "$OUT/files.txt")" \
	"$OUT/patch.zip"
