#!/bin/sh
# buildroot/scripts/build_all.sh - Build rootfs for all TrimUI devices
#
# Usage:
#   ./buildroot/scripts/build_all.sh           # Build all devices
#   ./buildroot/scripts/build_all.sh tg5050    # Build only TG5050
#   ./buildroot/scripts/build_all.sh tsp       # Build only TSP/Brick
#
# Prerequisites:
#   - Buildroot installed (or run with --setup to install)
#   - Internet connection (for downloading packages)
#   - ~10GB free disk space
#
# Output:
#   buildroot/output/rootfs-tg5050.ext2    (1GB, full tier)
#   buildroot/output/rootfs-tsp-brick.ext2 (512MB, minimal tier)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$BUILDROOT_DIR/output"
BUILDROOT_VERSION="2024.02"
BUILDROOT_URL="https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if Buildroot is installed
check_buildroot() {
    if [ ! -d "$BUILDROOT_DIR/buildroot-${BUILDROOT_VERSION}" ]; then
        log_warn "Buildroot not found. Downloading..."
        download_buildroot
    fi
}

# Download Buildroot
download_buildroot() {
    log_info "Downloading Buildroot ${BUILDROOT_VERSION}..."
    cd "$BUILDROOT_DIR"
    
    if command -v wget >/dev/null 2>&1; then
        wget "$BUILDROOT_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -LO "$BUILDROOT_URL"
    else
        log_error "Neither wget nor curl available"
        exit 1
    fi
    
    log_info "Extracting Buildroot..."
    tar xf "buildroot-${BUILDROOT_VERSION}.tar.xz"
    rm "buildroot-${BUILDROOT_VERSION}.tar.xz"
    
    log_info "Buildroot installed"
}

# Build for specific device
build_device() {
    local device="$1"
    local config="$2"
    local output_name="$3"
    
    log_info "Building for ${device}..."
    
    cd "$BUILDROOT_DIR/buildroot-${BUILDROOT_VERSION}"
    
    # Clean previous build
    make clean 2>/dev/null || true
    
    # Apply config
    make "$config"
    
    # Build
    make -j"$(nproc 2>/dev/null || echo 4)"
    
    # Copy output
    mkdir -p "$OUTPUT_DIR"
    cp output/images/rootfs.ext2 "$OUTPUT_DIR/${output_name}.ext2"
    
    log_info "Built: $OUTPUT_DIR/${output_name}.ext2"
}

# Build TG5050 (Full tier)
build_tg5050() {
    log_info "=== Building TG5050 (Full Tier) ==="
    log_info "Features: QT6, Wayland, Mesa3D, modern libraries"
    log_info "Size: ~1GB"
    
    build_device "TG5050" "trimui_tg5050_defconfig" "rootfs-tg5050"
}

# Build TSP/Brick (Minimal tier)
build_tsp_brick() {
    log_info "=== Building TSP/Brick (Minimal Tier) ==="
    log_info "Features: Modern glibc, Python, Node.js (no QT6/Wayland)"
    log_info "Size: ~512MB"
    
    build_device "TSP/Brick" "trimui_tsp_brick_defconfig" "rootfs-tsp-brick"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [DEVICE]

Build rootfs for TrimUI devices.

Options:
  tg5050    Build only for TrimUI Smart Pro S (TG5050)
  tsp       Build only for TrimUI Smart Pro and Brick
  all       Build for all devices (default)
  --setup   Download and setup Buildroot
  --help    Show this help message

Output:
  buildroot/output/rootfs-tg5050.ext2     (1GB, full tier)
  buildroot/output/rootfs-tsp-brick.ext2  (512MB, minimal tier)

Examples:
  $0              # Build all devices
  $0 tg5050       # Build only TG5050
  $0 tsp          # Build only TSP/Brick
  $0 --setup      # Setup Buildroot first
EOF
}

# Main
main() {
    local device="${1:-all}"
    
    case "$device" in
        tg5050)
            check_buildroot
            build_tg5050
            ;;
        tsp)
            check_buildroot
            build_tsp_brick
            ;;
        all)
            check_buildroot
            build_tg5050
            build_tsp_brick
            ;;
        --setup)
            download_buildroot
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown device: $device"
            usage
            exit 1
            ;;
    esac
    
    log_info "=== Build Complete ==="
    log_info "Output files:"
    ls -lh "$OUTPUT_DIR"/*.ext2 2>/dev/null || log_warn "No output files found"
}

main "$@"
