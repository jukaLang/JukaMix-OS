#!/bin/sh
# scripts/fetch_ppsspp.sh - Download and extract PPSSPP for TrimUI devices
#
# Downloads PPSSPP AppImage from GitHub releases and extracts it to get
# the native binary. Creates proper directory structure with config files.
#
# Usage:
#   scripts/fetch_ppsspp.sh              # Download if missing
#   scripts/fetch_ppsspp.sh --force      # Re-download
#   scripts/fetch_ppsspp.sh --version X  # Download specific version
#   JUKAMIX_SKIP_PPSSPP=1 scripts/fetch_ppsspp.sh  # Skip
#
# Exit codes: 0 success, 1 fetch failed, 2 usage.

set -u

# Allow skipping
[ -n "${JUKAMIX_SKIP_PPSSPP:-}" ] && { echo "fetch_ppsspp: skipped (JUKAMIX_SKIP_PPSSPP=1)"; exit 0; }

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Parse arguments
FORCE=0
VERSION="${JUKAMIX_PPSSPP_VERSION:-v1.20.4}"

while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=1; shift ;;
        --version) VERSION="$2"; shift 2 ;;
        *) 
            if [ -d "$1" ]; then
                root=$(CDPATH= cd -- "$1" && pwd)
            fi
            shift
            ;;
    esac
done

PPSSPP_BASE="$root/Emus/PSP/PPSSPP"
PPSSPP_BINARY="$PPSSPP_BASE/PPSSPPSDL"
PPSSPP_APPIMAGE="$PPSSPP_BASE/PPSSPP.AppImage"

# Check if already present
if [ -f "$PPSSPP_BINARY" ] && [ -x "$PPSSPP_BINARY" ] && [ "$FORCE" != "1" ]; then
    echo "fetch_ppsspp: present  $PPSSPP_BINARY"
    exit 0
fi

echo "fetch_ppsspp: PPSSPP $VERSION not found, downloading..."

# Create directory structure
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/Cheats"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/GAME"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/PLUGINS"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/PPSSPP_STATE"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/SAVEDATA"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/SYSTEM"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/CACHE"
mkdir -p "$PPSSPP_BASE/.config/ppsspp/PSP/TEXTURES"
mkdir -p "$PPSSPP_BASE/assets"
mkdir -p "$PPSSPP_BASE/config"

# Download URL
DOWNLOAD_URL="https://github.com/hrydgard/ppsspp/releases/download/${VERSION}/PPSSPP-${VERSION}-anylinux-aarch64.AppImage"

echo "fetch_ppsspp: downloading $DOWNLOAD_URL"

# Download with retry
tmpdir=$(mktemp -d)
download_ok=0

for attempt in 1 2 3; do
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$tmpdir/ppsspp.AppImage" "$DOWNLOAD_URL" 2>/dev/null && download_ok=1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$tmpdir/ppsspp.AppImage" "$DOWNLOAD_URL" 2>/dev/null && download_ok=1
    fi
    
    if [ "$download_ok" = "1" ] && [ -s "$tmpdir/ppsspp.AppImage" ]; then
        # Check it's not an HTML error page
        head -c 5 "$tmpdir/ppsspp.AppImage" | grep -q "<!DOC" && {
            echo "fetch_ppsspp: got HTML instead of archive" >&2
            download_ok=0
            rm -f "$tmpdir/ppsspp.AppImage"
        }
        [ "$download_ok" = "1" ] && break
    fi
    
    echo "fetch_ppsspp: attempt $attempt failed, retrying..."
    sleep 2
done

if [ "$download_ok" != "1" ]; then
    rm -rf "$tmpdir"
    echo "fetch_ppsspp: failed to download after 3 attempts" >&2
    exit 1
fi

echo "fetch_ppsspp: downloaded, extracting..."

# Extract AppImage (it's a self-extracting archive)
chmod +x "$tmpdir/ppsspp.AppImage"
cd "$tmpdir" || exit 1

# Extract using --appimage-extract
./ppsspp.AppImage --appimage-extract >/dev/null 2>&1 || {
    # If extraction fails, try mounting
    echo "fetch_ppsspp: trying alternative extraction..." >&2
    if command -v 7z >/dev/null 2>&1; then
        7z x -o"$tmpdir/extracted" "$tmpdir/ppsspp.AppImage" >/dev/null 2>&1
    fi
}

# Find the PPSSPPSDL binary
BINARY=""
for candidate in squashfs-root/usr/bin/PPSSPPSDL squashfs-root/PPSSPPSDL PPSSPPSDL; do
    if [ -f "$tmpdir/$candidate" ]; then
        BINARY="$tmpdir/$candidate"
        break
    fi
done

if [ -z "$BINARY" ]; then
    rm -rf "$tmpdir"
    echo "fetch_ppsspp: could not find PPSSPPSDL binary in AppImage" >&2
    exit 1
fi

# Copy binary
cp "$BINARY" "$PPSSPP_BINARY"
chmod +x "$PPSSPP_BINARY"

# Copy assets if extracted
if [ -d "$tmpdir/squashfs-root/assets" ]; then
    cp -r "$tmpdir/squashfs-root/assets/"* "$PPSSPP_BASE/assets/" 2>/dev/null || true
fi

# Copy config files if extracted
if [ -d "$tmpdir/squashfs-root/config" ]; then
    cp -r "$tmpdir/squashfs-root/config/"* "$PPSSPP_BASE/config/" 2>/dev/null || true
fi

# Cleanup
rm -rf "$tmpdir"

# Verify
if [ -f "$PPSSPP_BINARY" ] && [ -x "$PPSSPP_BINARY" ]; then
    SIZE=$(wc -c < "$PPSSPP_BINARY")
    echo "fetch_ppsspp: installed PPSSPPSDL ($SIZE bytes)"
    echo "fetch_ppsspp: binary: $PPSSPP_BINARY"
    exit 0
else
    echo "fetch_ppsspp: installation failed" >&2
    exit 1
fi
