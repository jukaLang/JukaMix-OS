#!/bin/sh
# JukaMix OS - build a single .ipk package (Entware-compatible tar.gz layout).
#
# Expected source layout:
#   <pkg>/control          Debian-style control file (Package, Version,
#                          Architecture, Depends, Description, ...)
#   <pkg>/data/            files installed relative to the destination root
#
# Optional maintainer scripts (top-level, run by the installer):
#   <pkg>/preinst <pkg>/postinst <pkg>/prerm <pkg>/postrm
#
# Usage: jukamix-mkpackage.sh <pkg-dir> <out-dir> [arch]
# The archive is written as <out-dir>/<Package>_<Version>_<arch>.ipk
#
# The resulting .ipk is a gzip tarball containing:
#   debian-binary        -> "2.0"
#   control.tar.gz       -> control
#   data.tar.gz          -> payload
#   preinst/postinst/... -> only when present
#
# This is the layout used by Entware's opkg; JukaMix's built-in client
# (tools/lib/jukamix-opkg.sh) consumes the same format.

set -u

PKG_DIR="${1:-}"
OUT_DIR="${2:-}"
ARCH="${3:-aarch64}"

usage() {
	sed -n '2,16p' "$0"
}

case "$PKG_DIR" in
	-h|--help) usage; exit 0 ;;
esac

[ -n "$PKG_DIR" ] && [ -n "$OUT_DIR" ] || { usage; exit 2; }
[ -d "$PKG_DIR" ] || { echo "package dir not found: $PKG_DIR" >&2; exit 2; }
[ -f "$PKG_DIR/control" ] || { echo "missing control file: $PKG_DIR/control" >&2; exit 2; }

# Fetch a control field (first match wins). Splits on the FIRST colon only
# so values may contain colons (URLs, times, etc.).
ctl_field() {
	awk -v k="$1" '
		{
			idx = index($0, ":")
			if (idx == 0) next
			key = substr($0, 1, idx - 1)
			val = substr($0, idx + 1)
			sub(/^[ \t]+/, "", val)
			if (key == k && !done) { print val; done = 1 }
		}
	' "$PKG_DIR/control"
}

NAME=$(ctl_field Package)
VERSION=$(ctl_field Version)
CTL_ARCH=$(ctl_field Architecture)
[ -n "$CTL_ARCH" ] && ARCH="$CTL_ARCH"
[ -n "$NAME" ] || { echo "control file has no Package field" >&2; exit 2; }
[ -n "$VERSION" ] || { echo "control file has no Version field" >&2; exit 2; }

_TMP=$(mktemp -d)
trap 'rm -rf "$_TMP"' EXIT INT TERM

# debian-binary marker.
printf '2.0\n' > "$_TMP/debian-binary"

# control archive: the control file only.
mkdir -p "$_TMP/ctl"
cp "$PKG_DIR/control" "$_TMP/ctl/control"
( cd "$_TMP/ctl" && tar -czf "$_TMP/control.tar.gz" control )

# data archive: payload files (reject absolute paths and '..').
if [ -d "$PKG_DIR/data" ]; then
	_bad=$(cd "$PKG_DIR/data" 2>/dev/null && find . -print | grep -E '(^\.\.|^[^.]/)' | head -n1)
	[ -n "$_bad" ] && { echo "unsafe path in data/: $_bad" >&2; exit 2; }
	( cd "$PKG_DIR/data" && tar -czf "$_TMP/data.tar.gz" . )
else
	( cd "$_TMP" && mkdir -p empty && tar -czf "$_TMP/data.tar.gz" -C empty . )
fi

# Optional maintainer scripts (top-level members of the .ipk).
for _s in preinst postinst prerm postrm; do
	[ -f "$PKG_DIR/$_s" ] && cp "$PKG_DIR/$_s" "$_TMP/$_s"
done
unset _s _bad

mkdir -p "$OUT_DIR"
# Resolve to an absolute path: the packaging runs inside a `cd "$_TMP"`
# subshell, so a relative OUT would otherwise be written into the temp dir
# (and lost when it is cleaned up).
OUT_DIR=$(CDPATH= cd -- "$OUT_DIR" && pwd)
OUT="$OUT_DIR/${NAME}_${VERSION}_${ARCH}.ipk"

# Include only the maintainer scripts that actually exist.
_items="debian-binary control.tar.gz data.tar.gz"
for _s in preinst postinst prerm postrm; do
	[ -f "$_TMP/$_s" ] && _items="$_items $_s"
done
unset _s
( cd "$_TMP" && tar -czf "$OUT" $_items )

echo "$OUT"
