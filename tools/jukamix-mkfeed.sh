#!/bin/sh
# JukaMix OS - build an opkg-compatible Packages index from a directory of
# .ipk files produced by tools/jukamix-mkpackage.sh.
#
# Outputs (in the same directory):
#   Packages      plain-text package index
#   Packages.gz   gzip-compressed copy (preferred by opkg)
#
# Each stanza contains Package, Version, Architecture, Depends, Description,
# Filename, Size and SHA256sum, so both opkg and the built-in JukaMix client
# can verify and install from this feed. When several versions of the same
# package are present, only the highest version is indexed (matching
# opkg-make-index behavior).
#
# Usage: jukamix-mkfeed.sh <feed-dir>

set -u

FEED_DIR="${1:-}"

usage() {
	sed -n '2,15p' "$0"
}

case "$FEED_DIR" in
	-h|--help) usage; exit 0 ;;
esac

[ -n "$FEED_DIR" ] || { usage; exit 2; }
[ -d "$FEED_DIR" ] || { echo "not a directory: $FEED_DIR" >&2; exit 2; }

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$1" | awk '{print $NF}'
	else
		echo ""
	fi
}

# Extract one control field from an .ipk (gzip tarball containing control.tar.gz).
# $1 = .ipk path, $2 = field name.
ipk_field() {
	_ipk="$1"; _k="$2"
	_d="$_TMP/ctl"
	rm -rf "$_d"; mkdir -p "$_d"
	if ! tar -xzf "$_ipk" -C "$_d" control.tar.gz 2>/dev/null; then
		rm -rf "$_d"
		return 1
	fi
	if ! tar -xzf "$_d/control.tar.gz" -C "$_d" control 2>/dev/null; then
		rm -rf "$_d"
		return 1
	fi
	awk -v k="$_k" '
		{
			idx = index($0, ":")
			if (idx == 0) next
			key = substr($0, 1, idx - 1)
			val = substr($0, idx + 1)
			sub(/^[ \t]+/, "", val)
			if (key == k && !done) { print val; done = 1 }
		}
	' "$_d/control"
	rm -rf "$_d"
}

_TMP=$(mktemp -d)
trap 'rm -rf "$_TMP"' EXIT INT TERM

# Pass 1: record each .ipk's package, sortable version key and filename.
: > "$_TMP/raw"
for _ipk in "$FEED_DIR"/*.ipk; do
	[ -f "$_ipk" ] || continue
	_name=${_ipk##*/}
	[ "$_name" = "*.ipk" ] && continue

	_pkg=$(ipk_field "$_ipk" Package)
	_ver=$(ipk_field "$_ipk" Version)
	[ -n "$_pkg" ] && [ -n "$_ver" ] || { echo "skipping (bad control): $_name" >&2; continue; }
	# Zero-pad each component so string sort == numeric sort.
	_key=$(printf '%s' "$_ver" | awk -F. '{printf("%010d.%010d.%010d.%010d", $1+0, $2+0, $3+0, $4+0)}')
	printf '%s\t%s\t%s\n' "$_pkg" "$_key" "$_name" >> "$_TMP/raw"
done

# Keep only the highest version per package.
sort -k1,1 -k2,2r "$_TMP/raw" 2>/dev/null | awk -F'\t' '!seen[$1]++ { print }' > "$_TMP/best"

# Pass 2: emit a full opkg stanza for each surviving .ipk.
: > "$FEED_DIR/Packages"
while IFS=$(printf '\t') read -r _pkg _key _name; do
	[ -n "$_name" ] || continue
	_ipk="$FEED_DIR/$_name"
	_arch=$(ipk_field "$_ipk" Architecture)
	_deps=$(ipk_field "$_ipk" Depends)
	_desc=$(ipk_field "$_ipk" Description)
	_size=$(wc -c < "$_ipk" | tr -d ' ')
	_sha=$(sha256_of "$_ipk")

	{
		printf 'Package: %s\n' "$_pkg"
		printf 'Version: %s\n' "$(ipk_field "$_ipk" Version)"
		printf 'Architecture: %s\n' "$_arch"
		[ -n "$_deps" ] && printf 'Depends: %s\n' "$_deps"
		[ -n "$_desc" ] && printf 'Description: %s\n' "$_desc"
		printf 'Filename: %s\n' "$_name"
		printf 'Size: %s\n' "$_size"
		printf 'SHA256sum: %s\n' "$_sha"
		printf '\n'
	} >> "$FEED_DIR/Packages"
done < "$_TMP/best"

gzip -c "$FEED_DIR/Packages" > "$FEED_DIR/Packages.gz" 2>/dev/null || \
	cp "$FEED_DIR/Packages" "$FEED_DIR/Packages.gz"

echo "wrote $FEED_DIR/Packages ($(grep -c '^Package:' "$FEED_DIR/Packages") packages)"
