#!/bin/sh
# scripts/fetch_ppsspp.sh - Download PPSSPP AppImage from GitHub releases.
#
# The PPSSPP AppImage is a self-contained binary that includes both GL and Vulkan
# backends. It runs on any Linux aarch64 system without additional dependencies.
#
# Usage:
#   scripts/fetch_ppsspp.sh [os-root]        # default: repo root
#   JUKAMIX_SKIP_PPSSPP=1 scripts/fetch_ppsspp.sh  # skip download
#
# Exit codes: 0 success, 1 fetch failed, 2 usage.

set -u

# Allow skipping (useful for dev builds or when AppImage already exists).
[ -n "${JUKAMIX_SKIP_PPSSPP:-}" ] && { echo "fetch_ppsspp: skipped (JUKAMIX_SKIP_PPSSPP=1)"; exit 0; }

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Optional os-root argument overrides the default.
if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
        root=$(CDPATH= cd -- "$1" && pwd)
    else
        echo "fetch_ppsspp: not a directory: $1" >&2
        exit 2
    fi
fi

PPSSPP_DIR="$root/Emus/PSP/PPSSPP"
PPSSPP_APPIMAGE="$PPSSPP_DIR/PPSSPP.AppImage"

# If the AppImage already exists, nothing to do.
if [ -s "$PPSSPP_APPIMAGE" ]; then
    echo "fetch_ppsspp: present  PPSSPP.AppImage ($(wc -c < "$PPSSPP_APPIMAGE") bytes)"
    exit 0
fi

# Download URL: hosted at hrydgard/ppsspp releases.
# Update this URL when upgrading PPSSPP.
PPSSPP_VERSION="${JUKAMIX_PPSSPP_VERSION:-v1.20.4}"
DOWNLOAD_URL="${JUKAMIX_PPSSPP_URL:-https://github.com/hrydgard/ppsspp/releases/download/${PPSSPP_VERSION}/PPSSPP-${PPSSPP_VERSION}-anylinux-aarch64.AppImage}"

mkdir -p "$PPSSPP_DIR"

echo "fetch_ppsspp: downloading $DOWNLOAD_URL"
if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --retry 3 -o "$PPSSPP_APPIMAGE.tmp" "$DOWNLOAD_URL"; then
        echo "fetch_ppsspp: failed to download $DOWNLOAD_URL" >&2
        rm -f "$PPSSPP_APPIMAGE.tmp"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --tries=3 -O "$PPSSPP_APPIMAGE.tmp" "$DOWNLOAD_URL"; then
        echo "fetch_ppsspp: failed to download $DOWNLOAD_URL" >&2
        rm -f "$PPSSPP_APPIMAGE.tmp"
        exit 1
    fi
else
    echo "fetch_ppsspp: neither curl nor wget available" >&2
    exit 1
fi

# Verify we didn't download an HTML error page.
head -c 5 "$PPSSPP_APPIMAGE.tmp" | grep -q "<!DOC" && {
    echo "fetch_ppsspp: got HTML instead of archive (release may not exist yet)" >&2
    rm -f "$PPSSPP_APPIMAGE.tmp"
    exit 1
}

chmod +x "$PPSSPP_APPIMAGE.tmp"
mv -f "$PPSSPP_APPIMAGE.tmp" "$PPSSPP_APPIMAGE"
echo "fetch_ppsspp: downloaded PPSSPP.AppImage ($(wc -c < "$PPSSPP_APPIMAGE") bytes)"
