#!/bin/bash
# fetch_retroarch.sh - Download RetroArch source for TrimUI cross-compilation
#
# Usage:
#   ./scripts/fetch_retroarch.sh 1.22.2     # Download source for this version
#   ./scripts/fetch_retroarch.sh latest      # Download latest release
#
# Note: TrimUI requires cross-compilation with their proprietary toolchain.
# This script downloads the source; cross-compile on a Linux x86_64 host
# with the TrimUI SDK installed.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/retroarch"
RETROARCH_DIR="$PROJECT_DIR/RetroArch"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

get_latest_version() {
    curl -s https://api.github.com/repos/libretro/RetroArch/releases/latest \
        | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//'
}

check_version() {
    local version="$1"
    curl -s -o /dev/null -w "%{http_code}" \
        "https://api.github.com/repos/libretro/RetroArch/releases/tags/v${version}"
}

download_source() {
    local version="$1"
    local url="https://github.com/libretro/RetroArch/archive/refs/tags/v${version}.tar.gz"
    local output="$BUILD_DIR/retroarch-${version}.tar.gz"

    mkdir -p "$BUILD_DIR"

    if [ -f "$output" ]; then
        log_info "Already downloaded: $output"
        return 0
    fi

    log_step "Downloading RetroArch v${version} source..."
    wget -q --show-progress "$url" -O "$output"

    log_step "Extracting..."
    cd "$BUILD_DIR"
    tar xzf "$output"
    mv "RetroArch-${version}" "retroarch-${version}" 2>/dev/null || true

    log_info "Source extracted to: $BUILD_DIR/retroarch-${version}"
}

create_placeholder() {
    local version="$1"
    local install_dir="$RETROARCH_DIR/ra64.trimui-${version}"

    if [ -f "$install_dir/ra64.trimui" ]; then
        log_info "Binary already exists: $install_dir/ra64.trimui"
        return 0
    fi

    mkdir -p "$install_dir"

    # Create a README with cross-compilation instructions
    cat > "$install_dir/README.md" << 'READMEEOF'
# RetroArch Cross-Compilation for TrimUI

## Prerequisites

1. Install TrimUI SDK (provided by TrimUI or community)
2. Set environment variables:
   ```bash
   export TRIMUI_SDK=/path/to/trimui-sdk
   export PATH=$TRIMUI_SDK/bin:$PATH
   ```

## Build Steps

```bash
cd build/retroarch/retroarch-VERSION

# Clean previous build
make clean 2>/dev/null || true

# Configure for TrimUI (A133/A523 aarch64)
./configure \
    --host=aarch64-linux-gnu \
    --prefix=/mnt/SDCARD/RetroArch/ra64.trimui-VERSION \
    --enable-sdl2 \
    --enable-alsa \
    --enable-egl \
    --enable-opengles \
    --enable-opengles3 \
    --enable-drm \
    --enable-freetype \
    --enable-zstd \
    --disable-qt \
    --disable-x11 \
    --disable-wayland \
    --disable-vulkan \
    --disable-ffmpeg \
    --disable-pulse \
    --disable-usb \
    --disable-cdiscord \
    --disable-lakka

# Build
make -j$(nproc)

# Install
make install DESTDIR=$PWD/install
cp install/mnt/SDCARD/RetroArch/ra64.trimui-VERSION/ra64.trimui \
   ../../RetroArch/ra64.trimui-VERSION/ra64.trimui
```

## Version History

- v1.22.2: Latest stable (Nov 2025)
- v1.20.0: Current default
- v1.18.0: Legacy
- v1.17.0: Legacy
- v1.15.0: Legacy
READMEEOF

    log_info "Created: $install_dir/README.md"
}

main() {
    local version="${1:-latest}"

    case "$version" in
        --help|-h)
            echo "Usage: $0 [version]"
            echo ""
            echo "Download RetroArch source for TrimUI cross-compilation."
            echo ""
            echo "Versions: 1.22.2, 1.20.0, 1.18.0, 1.17.0, 1.15.0, latest"
            exit 0
            ;;
    esac

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   RetroArch Source Fetcher${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ "$version" = "latest" ]; then
        log_step "Checking latest version..."
        version=$(get_latest_version)
        log_info "Latest version: $version"
    fi

    local status=$(check_version "$version")
    if [ "$status" != "200" ]; then
        log_error "Version v${version} not found (HTTP $status)"
        exit 1
    fi

    download_source "$version"
    create_placeholder "$version"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}         Download Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Source: build/retroarch/retroarch-${version}/"
    echo "Target: RetroArch/ra64.trimui-${version}/"
    echo ""
    echo "Next steps:"
    echo "  1. Cross-compile using TrimUI SDK (see README.md)"
    echo "  2. Copy ra64.trimui to RetroArch/ra64.trimui-${version}/"
    echo "  3. Update launchers to use the new version"
    echo ""
}

main "$@"
