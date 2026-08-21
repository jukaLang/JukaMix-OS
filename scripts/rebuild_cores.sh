#!/bin/sh
# rebuild_cores.sh - Download and package all latest RetroArch libretro cores
#
# This script downloads the latest pre-built aarch64 cores from RetroArch's
# official buildbot and packages them into cores.7z for distribution.
#
# Usage:
#   ./scripts/rebuild_cores.sh              # Build cores.7z
#   ./scripts/rebuild_cores.sh --list       # List all required cores
#   ./scripts/rebuild_cores.sh --verify     # Verify existing cores.7z
#
# Requirements:
#   - 7z (p7zip-full)
#   - wget or curl
#   - ~2GB free disk space
#
# Output:
#   RetroArch/.retroarch/cores/cores.7z

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORES_DIR="$ROOT_DIR/RetroArch/.retroarch/cores"
BUILD_DIR="$ROOT_DIR/build/cores"
OUTPUT="$CORES_DIR/cores.7z"

# All cores we need (from core_folders.csv + new additions)
REQUIRED_CORES="
2048
81
a5200
ardens
arduous
atari800
bluemsx
bnes
cap32
chailove
crocods
daphne
desmume2015
dosbox
dosbox_pure
duckstation
easyrpg
ecwolf
fbalpha2012
fbneo
fceumm
flycast
fmsx
freechaf
freeintv
fuse
gambatte
gearboy
gearcoleco
gearsystem
genesis_plus_gx
gme
gpsp
gw
handy
hatari
libgametank
lowresnx
lutro
mame2003_plus
mednafen_lynx
mednafen_ngp
mednafen_pce_fast
mednafen_pcfx
mednafen_supafaust
mednafen_supergrafx
mednafen_vb
mednafen_wswan
melonds
mesen
meteor
mgba
mupen64plus
mupen64plus_next
neocd
nestopia
np2kai
numero
o2em
opera
parallel_n64
pcsx_rearmed
picodrive
pokemini
potator
ppsspp
prboom
prosystem
puae2021
px68k
quasi88
quicknes
race
reminiscence
sameboy
scummvm
snes9x
snes9x2002
snes9x2005
snes9x2010
stella
stella2014
swanstation
tgbdual
theodore
tic80
tyrquake
uae4arm
uzem
vba_next
vbam
vecx
vemulator
vice_x128
vice_x64
vice_x64sc
vice_xvic
virtualjaguar
wasm4
x1
xrick
yabasanshiro
yabause
"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# Check dependencies
check_deps() {
    local missing=""
    for cmd in 7z wget; do
        command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
    done
    if [ -n "$missing" ]; then
        log_error "Missing dependencies:$missing"
        log_error "Install: sudo apt-get install -y p7zip-full wget"
        exit 1
    fi
}

# List all required cores
list_cores() {
    echo "Required cores:"
    echo "$REQUIRED_CORES" | grep -v '^$' | sort | while read -r core; do
        echo "  ${core}_libretro.so"
    done
}

# Download a core from RetroArch buildbot
download_core() {
    local core_name="$1"
    local so_file="${core_name}_libretro.so"
    local url="https://buildbot.libretro.com/nightly/linux/aarch64/latest/${so_file}"
    local dest="$BUILD_DIR/$so_file"

    if [ -f "$dest" ]; then
        log_info "Already downloaded: $so_file"
        return 0
    fi

    log_info "Downloading: $so_file"
    if wget -q --show-progress "$url" -O "$dest" 2>/dev/null; then
        chmod +x "$dest"
        return 0
    else
        log_warn "Failed to download: $so_file (may not be available for aarch64)"
        rm -f "$dest"
        return 1
    fi
}

# Build cores.7z
build_cores() {
    log_step "Creating build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    local downloaded=0
    local failed=0

    log_step "Downloading cores..."
    echo "$REQUIRED_CORES" | grep -v '^$' | while read -r core; do
        if download_core "$core"; then
            downloaded=$((downloaded + 1))
        else
            failed=$((failed + 1))
        fi
    done

    log_step "Packaging cores.7z..."
    cd "$BUILD_DIR"
    7z a -t7z -mx=7 "$OUTPUT" *.so 2>/dev/null

    if [ -f "$OUTPUT" ]; then
        local size=$(ls -lh "$OUTPUT" | awk '{print $5}')
        local count=$(7z l "$OUTPUT" 2>/dev/null | grep "\.so$" | wc -l)
        log_info "Created: $OUTPUT ($size, $count cores)"
    else
        log_error "Failed to create cores.7z"
        exit 1
    fi

    # Cleanup
    rm -rf "$BUILD_DIR"
}

# Verify existing cores.7z
verify_cores() {
    if [ ! -f "$OUTPUT" ]; then
        log_error "cores.7z not found: $OUTPUT"
        exit 1
    fi

    log_step "Verifying cores.7z..."
    local count=$(7z l "$OUTPUT" 2>/dev/null | grep "\.so$" | wc -l)
    log_info "cores.7z contains $count cores"

    local missing=0
    echo "$REQUIRED_CORES" | grep -v '^$' | while read -r core; do
        local so_file="${core}_libretro.so"
        if 7z l "$OUTPUT" 2>/dev/null | grep -q "$so_file"; then
            echo "  ✓ $so_file"
        else
            echo "  ✗ $so_file (MISSING)"
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -gt 0 ]; then
        log_warn "$missing cores missing from archive"
        log_info "Run: $0 (without flags) to rebuild"
    else
        log_info "All required cores present"
    fi
}

# Main
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--list|--verify]"
        echo ""
        echo "Rebuilds cores.7z with all latest RetroArch libretro cores."
        echo ""
        echo "Options:"
        echo "  --list      List all required cores"
        echo "  --verify    Verify existing cores.7z"
        echo "  (no args)   Download and rebuild cores.7z"
        ;;
    --list)
        list_cores
        ;;
    --verify)
        check_deps
        verify_cores
        ;;
    *)
        check_deps
        build_cores
        ;;
esac
