#!/bin/bash
# build-rootfs.sh - Standalone Buildroot build for TrimUI devices
#
# This script builds rootfs files for all TrimUI devices.
# Run on a Linux machine (not Windows/MSYS).
#
# Usage:
#   ./build-rootfs.sh              # Build all devices
#   ./build-rootfs.sh tg5050       # Build only TG5050
#   ./build-rootfs.sh tsp          # Build only TSP/Brick
#   ./build-rootfs.sh --clean      # Clean build artifacts
#
# Output:
#   output/rootfs-tg5050.ext2      (1GB, full tier - QT6, Wayland)
#   output/rootfs-tsp-brick.ext2   (512MB, minimal tier - no QT6)
#
# Requirements:
#   - Linux (Ubuntu 22.04+ recommended)
#   - build-essential, libncurses-dev, python3, git, wget, curl
#   - ~10GB free disk space
#   - Internet connection

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDROOT_DIR="$SCRIPT_DIR/buildroot"
BUILDROOT_VERSION="2024.02"
BUILDROOT_URL="https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.xz"
OUTPUT_DIR="$SCRIPT_DIR/output"

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

# Check if running on Linux
check_linux() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script requires Linux"
        log_error "On Windows: use WSL or Docker"
        log_error "  wsl --install -d Ubuntu"
        exit 1
    fi
}

# Check dependencies
check_deps() {
    local missing=()
    
    for cmd in gcc make python3 git wget curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install with: sudo apt-get install -y build-essential python3 git wget curl"
        exit 1
    fi
    
    log_info "All dependencies found"
}

# Install Buildroot
install_buildroot() {
    if [ -d "$BUILDROOT_DIR/buildroot-$BUILDROOT_VERSION" ]; then
        log_info "Buildroot already installed"
        return 0
    fi
    
    log_step "Downloading Buildroot $BUILDROOT_VERSION..."
    mkdir -p "$BUILDROOT_DIR"
    cd "$BUILDROOT_DIR"
    
    wget -q --show-progress "$BUILDROOT_URL" -O "buildroot-${BUILDROOT_VERSION}.tar.xz"
    
    log_step "Extracting Buildroot..."
    tar xf "buildroot-${BUILDROOT_VERSION}.tar.xz"
    rm "buildroot-${BUILDROOT_VERSION}.tar.xz"
    
    log_info "Buildroot installed"
}

# Copy device configs
setup_configs() {
    local br_dir="$BUILDROOT_DIR/buildroot-$BUILDROOT_VERSION"
    
    log_step "Setting up device configs..."
    
    # TG5050 config (Full tier)
    cat > "$br_dir/configs/trimui_tg5050_defconfig" << 'EOF'
# TrimUI Smart Pro S (TG5050) - Full Tier
BR2_aarch64=y
BR2_cortex_a73=y
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
BR2_TOOLCHAIN_EXTERNAL_PATH="$(BR2_EXTERNAL TrimUI_PATH)/toolchain"
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX="aarch64-buildroot-linux-gnu"
BR2_TOOLCHAIN_EXTERNAL_GCC_13=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_GLIBC=y
BR2_TARGET_ROOTFS_EXT2=y
BR2_TARGET_ROOTFS_EXT2_4=y
BR2_TARGET_ROOTFS_EXT2_SIZE="1G"
BR2_TARGET_ROOTFS_EXT2_LABEL="BUILDROOT"
BR2_TARGET_GENERIC_HOSTNAME="jukamix-tg5050"
BR2_INIT_SYSV=y
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_MDEV=y
BR2_PACKAGE_GLIBC=y
BR2_PACKAGE_GLIBC_2_44=y
BR2_PACKAGE_BASH=y
BR2_PACKAGE_COREUTILS=y
BR2_PACKAGE_FINDUTILS=y
BR2_PACKAGE_GREP=y
BR2_PACKAGE_SED=y
BR2_PACKAGE_UTIL_LINUX=y
BR2_PACKAGE_GCC=y
BR2_PACKAGE_GCC_13=y
BR2_PACKAGE_MAKE=y
BR2_PACKAGE_PKG_CONFIG=y
BR2_PACKAGE_QT6=y
BR2_PACKAGE_QT6BASE=y
BR2_PACKAGE_QT6WAYLAND=y
BR2_PACKAGE_MESA3D=y
BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_FREEDRENO=y
BR2_PACKAGE_MESA3D_OPENGL_ES=y
BR2_PACKAGE_WAYLAND=y
BR2_PACKAGE_WAYLAND_PROTOCOLS=y
BR2_PACKAGE_LIBDRM=y
BR2_PACKAGE_CURL=y
BR2_PACKAGE_WGET=y
BR2_PACKAGE_OPENSSL=y
BR2_PACKAGE_OPENSSL_3=y
BR2_PACKAGE_PYTHON3=y
BR2_PACKAGE_PYTHON3_12=y
BR2_PACKAGE_NODEJS=y
BR2_PACKAGE_NODEJS_20=y
BR2_PACKAGE_ZSTD=y
BR2_PACKAGE_XZ=y
BR2_PACKAGE_HTOP=y
BR2_PACKAGE_NANO=y
BR2_PACKAGE_TREE=y
EOF

    # TSP/Brick config (Minimal tier)
    cat > "$br_dir/configs/trimui_tsp_brick_defconfig" << 'EOF'
# TrimUI Smart Pro / Brick - Minimal Tier
BR2_aarch64=y
BR2_cortex_a53=y
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
BR2_TOOLCHAIN_EXTERNAL_PATH="$(BR2_EXTERNAL TrimUI_PATH)/toolchain"
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX="aarch64-buildroot-linux-gnu"
BR2_TOOLCHAIN_EXTERNAL_GCC_13=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_GLIBC=y
BR2_TARGET_ROOTFS_EXT2=y
BR2_TARGET_ROOTFS_EXT2_4=y
BR2_TARGET_ROOTFS_EXT2_SIZE="512M"
BR2_TARGET_ROOTFS_EXT2_LABEL="BUILDROOT"
BR2_TARGET_GENERIC_HOSTNAME="jukamix-tsp-brick"
BR2_INIT_SYSV=y
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_MDEV=y
BR2_PACKAGE_GLIBC=y
BR2_PACKAGE_GLIBC_2_44=y
BR2_PACKAGE_BASH=y
BR2_PACKAGE_COREUTILS=y
BR2_PACKAGE_FINDUTILS=y
BR2_PACKAGE_GREP=y
BR2_PACKAGE_SED=y
BR2_PACKAGE_UTIL_LINUX=y
BR2_PACKAGE_GCC=y
BR2_PACKAGE_GCC_13=y
BR2_PACKAGE_MAKE=y
BR2_PACKAGE_PKG_CONFIG=y
BR2_PACKAGE_MESA3D=y
BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_FREEDRENO=y
BR2_PACKAGE_MESA3D_OPENGL_ES=y
BR2_PACKAGE_LIBDRM=y
BR2_PACKAGE_CURL=y
BR2_PACKAGE_WGET=y
BR2_PACKAGE_OPENSSL=y
BR2_PACKAGE_OPENSSL_3=y
BR2_PACKAGE_PYTHON3=y
BR2_PACKAGE_PYTHON3_12=y
BR2_PACKAGE_NODEJS=y
BR2_PACKAGE_NODEJS_20=y
BR2_PACKAGE_ZSTD=y
BR2_PACKAGE_XZ=y
BR2_PACKAGE_HTOP=y
BR2_PACKAGE_NANO=y
EOF

    log_info "Device configs created"
}

# Build for specific device
build_device() {
    local device="$1"
    local config="$2"
    local output_name="$3"
    local br_dir="$BUILDROOT_DIR/buildroot-$BUILDROOT_VERSION"
    
    log_step "Building $device..."
    
    cd "$br_dir"
    
    # Clean previous build
    make clean 2>/dev/null || true
    
    # Apply config
    make "$config"
    
    # Build
    log_info "Compiling (this may take 20-40 minutes)..."
    make -j$(nproc)
    
    # Copy output
    mkdir -p "$OUTPUT_DIR"
    cp output/images/rootfs.ext2 "$OUTPUT_DIR/${output_name}.ext2"
    
    log_info "Built: $OUTPUT_DIR/${output_name}.ext2 ($(ls -lh "$OUTPUT_DIR/${output_name}.ext2" | awk '{print $5}'))"
}

# Build TG5050
build_tg5050() {
    log_step "=== Building TG5050 (Full Tier) ==="
    log_info "Features: QT6, Wayland, Mesa3D, modern libraries"
    build_device "TG5050" "trimui_tg5050_defconfig" "rootfs-tg5050"
}

# Build TSP/Brick
build_tsp_brick() {
    log_step "=== Building TSP/Brick (Minimal Tier) ==="
    log_info "Features: Modern glibc, Python, Node.js (no QT6/Wayland)"
    build_device "TSP/Brick" "trimui_tsp_brick_defconfig" "rootfs-tsp-brick"
}

# Clean build
clean_build() {
    log_step "Cleaning build artifacts..."
    rm -rf "$BUILDROOT_DIR/buildroot-$BUILDROOT_VERSION/output"
    rm -rf "$OUTPUT_DIR"
    log_info "Clean complete"
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
  --clean   Clean build artifacts
  --help    Show this help message

Output:
  output/rootfs-tg5050.ext2     (1GB, full tier)
  output/rootfs-tsp-brick.ext2  (512MB, minimal tier)

Examples:
  $0              # Build all devices
  $0 tg5050       # Build only TG5050
  $0 --clean      # Clean build artifacts

Requirements:
  - Linux (Ubuntu 22.04+ recommended)
  - build-essential, libncurses-dev, python3, git, wget, curl
  - ~10GB free disk space
  - Internet connection

EOF
}

# Main
main() {
    local device="${1:-all}"
    
    case "$device" in
        --clean)
            clean_build
            exit 0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
    esac
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   JukaMix Buildroot Builder${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Check environment
    check_linux
    check_deps
    
    # Setup
    install_buildroot
    setup_configs
    
    # Build
    case "$device" in
        tg5050)
            build_tg5050
            ;;
        tsp)
            build_tsp_brick
            ;;
        all)
            build_tg5050
            build_tsp_brick
            ;;
        *)
            log_error "Unknown device: $device"
            usage
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}         Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Output files:"
    ls -lh "$OUTPUT_DIR"/*.ext2 2>/dev/null || echo "No output files"
    echo ""
    echo "Next steps:"
    echo "  1. Upload to GitHub release"
    echo "  2. Download on device with: ./buildroot/scripts/fetch-rootfs.sh"
    echo "  3. Start chroot with: ./buildroot/scripts/chroot-manager.sh start"
}

main "$@"
