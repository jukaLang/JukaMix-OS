#!/bin/sh
# scripts/fetch_java.sh - Download FreeJ2ME Java ME emulator
#
# FreeJ2ME is a J2ME (Java 2 Micro Edition) emulator that runs
# old mobile phone games (.jar files) on modern systems.
#
# Usage:
#   scripts/fetch_java.sh              # Download if missing
#   scripts/fetch_java.sh --force      # Re-download
#   JUKAMIX_SKIP_JAVA=1 scripts/fetch_java.sh  # Skip
#
# Exit codes: 0 success, 1 fetch failed, 2 usage.

set -u

# Allow skipping
[ -n "${JUKAMIX_SKIP_JAVA:-}" ] && { echo "fetch_java: skipped (JUKAMIX_SKIP_JAVA=1)"; exit 0; }

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Optional os-root argument
if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
        root=$(CDPATH= cd -- "$1" && pwd)
    elif [ "$1" = "--force" ]; then
        FORCE=1
    else
        echo "fetch_java: not a directory: $1" >&2
        exit 2
    fi
fi

JAVA_BASE="$root/Emus/JAVA"
JAVA_HOME="$JAVA_BASE/zulu17"

# Check if already present
if [ -f "$JAVA_HOME/bin/java" ] && [ -f "$JAVA_HOME/bin/freej2me-sdl.jar" ] && [ "${FORCE:-}" != "1" ]; then
    echo "fetch_java: present  Zulu JDK + FreeJ2ME"
    exit 0
fi

echo "fetch_java: FreeJ2ME requires manual installation"
echo ""
echo "  FreeJ2ME is a J2ME emulator for running old mobile phone games."
echo "  It needs:"
echo "    1. Zulu JDK 17 (aarch64 Linux)"
echo "    2. FreeJ2ME-SDL (the emulator)"
echo ""
echo "  To install manually:"
echo "    1. Download Zulu JDK 17 for aarch64 Linux:"
echo "       https://www.azul.com/downloads/#zulu"
echo "    2. Download FreeJ2ME-SDL:"
echo "       https://github.com/AshkanAnoworked/freej2me/releases"
echo "    3. Extract to: $JAVA_BASE/"
echo ""
echo "  The expected structure is:"
echo "    $JAVA_BASE/zulu17/bin/java"
echo "    $JAVA_BASE/zulu17/bin/freej2me-sdl.jar"
echo "    $JAVA_BASE/zulu17/bin/sdl_interface"
echo "    $JAVA_BASE/timidity/timidity.cfg"
echo ""

# Try to auto-fetch if we have the URLs
# Note: These URLs may change - update as needed
FREEJ2ME_URL="${JUKAMIX_FREEJ2ME_URL:-https://github.com/AshkanAnoworked/freej2me/releases/download/v0.4.0/freej2me-sdl-linux-aarch64.zip}"

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    echo "Attempting auto-download of FreeJ2ME..."
    
    mkdir -p "$JAVA_BASE"
    tmpdir=$(mktemp -d)
    
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$tmpdir/freej2me.zip" "$FREEJ2ME_URL" 2>/dev/null
    else
        wget -q --tries=3 -O "$tmpdir/freej2me.zip" "$FREEJ2ME_URL" 2>/dev/null
    fi
    
    if [ -s "$tmpdir/freej2me.zip" ]; then
        # Check it's not an HTML error page
        head -c 5 "$tmpdir/freej2me.zip" | grep -q "<!DOC" && {
            echo "fetch_java: got HTML instead of archive" >&2
            rm -rf "$tmpdir"
            exit 1
        }
        
        echo "fetch_java: downloaded, extracting..."
        if command -v unzip >/dev/null 2>&1; then
            unzip -o "$tmpdir/freej2me.zip" -d "$JAVA_BASE" >/dev/null 2>&1
        elif command -v 7z >/dev/null 2>&1; then
            7z x -o"$JAVA_BASE" "$tmpdir/freej2me.zip" >/dev/null 2>&1
        else
            echo "fetch_java: need unzip or 7z to extract" >&2
            rm -rf "$tmpdir"
            exit 1
        fi
        
        rm -rf "$tmpdir"
        
        if [ -f "$JAVA_HOME/bin/java" ]; then
            chmod +x "$JAVA_HOME/bin/java" "$JAVA_HOME/bin/freej2me-sdl.jar" "$JAVA_HOME/bin/sdl_interface" 2>/dev/null
            echo "fetch_java: installed successfully"
            exit 0
        fi
    fi
    
    rm -rf "$tmpdir"
    echo "fetch_java: auto-download failed (URL may be incorrect)" >&2
    echo "fetch_java: please install manually using the instructions above" >&2
    exit 1
else
    echo "fetch_java: neither curl nor wget available" >&2
    echo "fetch_java: please install manually" >&2
    exit 1
fi
