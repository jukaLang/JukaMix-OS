#!/bin/sh
# scripts/fetch_cores.sh - Download RetroArch cores archive from GitHub releases.
#
# The cores.7z (~335MB) is too large to track in git (GitHub limit: 100MB).
# It's uploaded as a release asset with the first release, then downloaded
# by subsequent builds.
#
# Usage:
#   scripts/fetch_cores.sh [os-root]        # default: repo root
#   JUKAMIX_SKIP_CORES=1 scripts/fetch_cores.sh  # skip download
#
# Exit codes: 0 success, 1 fetch failed, 2 usage.

set -u

# Allow skipping (useful for dev builds or when cores.7z already exists).
[ -n "${JUKAMIX_SKIP_CORES:-}" ] && { echo "fetch_cores: skipped (JUKAMIX_SKIP_CORES=1)"; exit 0; }

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Optional os-root argument overrides the default.
if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
        root=$(CDPATH= cd -- "$1" && pwd)
    else
        echo "fetch_cores: not a directory: $1" >&2
        exit 2
    fi
fi

CORES_DIR="$root/RetroArch/.retroarch/cores"
CORES_ARCHIVE="$CORES_DIR/cores.7z"

# If the archive already exists, nothing to do.
if [ -s "$CORES_ARCHIVE" ]; then
    echo "fetch_cores: present  cores.7z ($(wc -c < "$CORES_ARCHIVE") bytes)"
    exit 0
fi

# Download URL: hosted at jukaLang/Packages repo (too large for git).
DOWNLOAD_URL="${JUKAMIX_CORES_URL:-https://github.com/jukaLang/Packages/releases/download/cores/cores.7z}"

mkdir -p "$CORES_DIR"

echo "fetch_cores: downloading $DOWNLOAD_URL"
if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --retry 3 -o "$CORES_ARCHIVE.tmp" "$DOWNLOAD_URL"; then
        echo "fetch_cores: failed to download $DOWNLOAD_URL" >&2
        rm -f "$CORES_ARCHIVE.tmp"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --tries=3 -O "$CORES_ARCHIVE.tmp" "$DOWNLOAD_URL"; then
        echo "fetch_cores: failed to download $DOWNLOAD_URL" >&2
        rm -f "$CORES_ARCHIVE.tmp"
        exit 1
    fi
else
    echo "fetch_cores: neither curl nor wget available" >&2
    exit 1
fi

# Verify we didn't download an HTML error page.
head -c 5 "$CORES_ARCHIVE.tmp" | grep -q "<!DOC" && {
    echo "fetch_cores: got HTML instead of archive (release may not exist yet)" >&2
    rm -f "$CORES_ARCHIVE.tmp"
    exit 1
}

mv -f "$CORES_ARCHIVE.tmp" "$CORES_ARCHIVE"
echo "fetch_cores: downloaded cores.7z ($(wc -c < "$CORES_ARCHIVE") bytes)"
