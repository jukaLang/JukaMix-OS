#!/bin/sh
# Generate a signed-OTA-compatible manifest.txt from a built JukaMix OS tree.
#
# Emits one line per OS file (user data and build artifacts excluded), using
# TAB separators so paths with spaces or UTF-8 characters survive intact:
#   install\t<relpath>\t/mnt/SDCARD/<relpath>\t<sha256>[\texecutable]
#
# The OTA engine (jukamix-ota.sh) consumes this manifest to apply the update
# transactionally: stage -> verify signature + checksums -> backup -> apply ->
# roll back on failure. Files under protected user-data directories are never
# listed, and the engine re-checks every destination at apply time.

set -u

OS_ROOT="${1:-}"
OUT="${2:-}"
DEST_ROOT="${3:-/mnt/SDCARD}"

if [ -z "$OS_ROOT" ] || [ -z "$OUT" ]; then
	echo "usage: make-ota-manifest.sh <os-root> <out-manifest> [dest-root]" >&2
	exit 2
fi
if [ ! -d "$OS_ROOT" ]; then
	echo "not a directory: $OS_ROOT" >&2
	exit 2
fi

# Source the shared sha256 helper (mirrors update_common/jukamix-update).
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$SCRIPT_DIR/lib/jukamix-update.sh" ]; then
	. "$SCRIPT_DIR/lib/jukamix-update.sh" 2>/dev/null
fi

# Protected user-data directories (must never be overwritten by an OS update).
USER_DATA='Roms ROMs BIOS Saves States Screenshots .media Themes UserConfig'
# Host-side scaffolding never shipped in the image (kept in sync with
# scripts/build_release.sh and the CI zip step).
EXTRA_SKIP='.git .github _assets scripts tests schemas packages .gitignore .gitattributes'

# Normalize OS_ROOT (strip trailing slash).
OS_ROOT=$(cd "$OS_ROOT" && pwd)

: > "$OUT"

find "$OS_ROOT" -type f | while IFS= read -r _f; do
	_rel=${_f#"$OS_ROOT"/}
	_base=${_rel%%/*}
	_skip=0
	for _ud in $USER_DATA $EXTRA_SKIP; do
		[ "$_base" = "$_ud" ] && _skip=1 && break
	done
	# Never list the manifest we are generating, or wifi credentials.
	case "$_rel" in
		manifest.txt|*/jukamix-ota-manifest.txt|*/etc/wifi/*) _skip=1 ;;
	esac
	[ "$_skip" -eq 1 ] && continue

	_sha=$(jukamix_update_sha256 "$_f" 2>/dev/null)
	[ -z "$_sha" ] && continue
	# Executable flag: test -x is a shell builtin (no ls/cut pipeline). On a
	# noexec filesystem it reports false, which is the desired behavior.
	if [ -x "$_f" ]; then
		printf 'install\t%s\t%s/%s\t%s\texecutable\n' "$_rel" "$DEST_ROOT" "$_rel" "$_sha" >> "$OUT"
	else
		printf 'install\t%s\t%s/%s\t%s\n' "$_rel" "$DEST_ROOT" "$_rel" "$_sha" >> "$OUT"
	fi
done

echo "wrote $OUT ($(wc -l < "$OUT") files)"
