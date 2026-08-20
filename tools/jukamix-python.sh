#!/bin/sh
# JukaMix OS - standalone CPython installer/upgrader.
#
# Downloads the newest aarch64 GNU (glibc) CPython from python-build-standalone
# and installs it under /mnt/SDCARD/System/python. The python3/python launchers
# shipped in System/bin automatically prefer it once installed, so this can be
# re-run later to upgrade in place.
#
# Usage:
#   jukamix-python.sh             install/upgrade to the latest Python
#   jukamix-python.sh --status    show the active Python
#   jukamix-python.sh --help      show this help

ROOT="${JUKAMIX_ROOT:-/mnt/SDCARD}"
REPO="${JUKAMIX_PYTHON_REPO:-astral-sh/python-build-standalone}"
API="https://api.github.com/repos/$REPO/releases/latest"
PREFIX="$ROOT/System/python"
SEL_FILE="$ROOT/System/etc/python-path.txt"
ARCH="aarch64-unknown-linux-gnu"
FLAVOR="install_only_stripped"

# Pure helper: echo the newest matching asset name from a release JSON blob.
jukamix_python_latest_asset() {
    if command -v jq >/dev/null 2>&1; then
        _names=$(printf '%s\n' "$1" | jq -r '.assets[].name' 2>/dev/null)
    else
        # jq-free fallback: pull `"name": "..."` values out of the JSON.
        _names=$(printf '%s\n' "$1" | grep -oE '"name": *"[^"]*"' | sed 's/.*"name": *"//; s/"$//')
    fi
    printf '%s\n' "$_names" \
        | grep -E "^cpython-[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+-$ARCH-$FLAVOR\.tar\.gz$" \
        | awk -F'[-.+]' '{ k = $2 * 1000000 + $3 * 1000 + $4; print k "\t" $0 }' \
        | sort -n | tail -n1 | cut -f2-
}

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        cat <<'EOF'
Usage: jukamix-python.sh [--status]
Install or upgrade the standalone CPython on JukaMix OS. Downloads the newest
aarch64 glibc build from python-build-standalone and makes python3 prefer it.
EOF
        exit 0
    fi

    if [ "${1:-}" = "--status" ]; then
        sel=$(cat "$SEL_FILE" 2>/dev/null)
        if [ -n "$sel" ] && [ -x "$sel" ]; then
            "$sel" --version 2>&1 || true
            echo "selected: $sel"
        else
            "$ROOT/System/bin/python3.11" --version 2>&1 || echo "python3.11 (bundled)"
            echo "selected: (bundled python3.11)"
        fi
        exit 0
    fi

    command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }
    command -v tar >/dev/null 2>&1 || { echo "error: tar is required" >&2; exit 1; }

    info=$(curl -k -sL "$API") || { echo "error: failed to query releases" >&2; exit 1; }
    asset=$(jukamix_python_latest_asset "$info")
    [ -n "$asset" ] || { echo "error: no matching $ARCH asset in latest release" >&2; exit 1; }
    url="https://github.com/$REPO/releases/latest/download/$asset"

    tmp=$(mktemp -d) || exit 1
    trap 'rm -rf "$tmp"' EXIT INT TERM

    echo "Downloading $asset ..."
    if ! curl -k -sL "$url" -o "$tmp/python.tar.gz"; then
        echo "error: download failed" >&2
        exit 1
    fi

    echo "Extracting ..."
    mkdir -p "$tmp/x"
    if ! tar -xzf "$tmp/python.tar.gz" -C "$tmp/x"; then
        echo "error: extraction failed" >&2
        exit 1
    fi

    # Locate the real (non-symlink) versioned interpreter binary.
    pybin=$(find "$tmp/x" -type f -path '*/bin/python3.[0-9]*' ! -name '*-config' | head -n1)
    [ -n "$pybin" ] || { echo "error: interpreter not found in archive" >&2; exit 1; }
    if ! "$pybin" --version >/dev/null 2>&1; then
        echo "error: downloaded interpreter failed to run" >&2
        exit 1
    fi

    src_prefix=$(dirname "$(dirname "$pybin")")
    echo "Installing to $PREFIX ..."
    rm -rf "$PREFIX"
    mkdir -p "$PREFIX"

    # Copy regular files only: FAT32 cannot store symlinks and the launcher
    # already provides the unversioned python3 entry point.
    (cd "$src_prefix" && find . -type f | while IFS= read -r f; do
        mkdir -p "$PREFIX/$(dirname "$f")"
        cp -f "$f" "$PREFIX/$f"
    done)

    newbin=$(find "$PREFIX" -type f -path '*/bin/python3.[0-9]*' ! -name '*-config' | head -n1)
    [ -n "$newbin" ] || { echo "error: installed interpreter missing" >&2; exit 1; }
    if ! "$newbin" --version; then
        echo "error: installed interpreter failed to run" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$SEL_FILE")"
    echo "$newbin" > "$SEL_FILE"
    echo "Active Python set in $SEL_FILE"
}

# Only run when executed directly, so the helper can be sourced by tests.
[ "${0##*/}" = "jukamix-python.sh" ] && main "$@"
